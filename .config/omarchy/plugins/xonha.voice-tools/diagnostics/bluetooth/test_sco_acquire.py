#!/usr/bin/env python3
"""Compile the actual acquire functions with mocked I/O; no Bluetooth access.

This is a focused reproduction harness, not PipeWire's full integration suite.
Usage: test-sco-acquire.py <backend-native.c> <bluez5-dbus.c>
"""
import pathlib
import subprocess
import sys
import tempfile


def function(path, signature):
    source = pathlib.Path(path).read_text()
    start = source.index(signature + "\n{")
    end = source.index("\n}", start) + 2
    return source[start:end]


stub = r'''
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
#include <stdio.h>
#include <stdint.h>
enum { SPA_BT_TRANSPORT_STATE_ERROR = -1, SPA_BT_TRANSPORT_STATE_IDLE,
       SPA_BT_TRANSPORT_STATE_PENDING, SPA_BT_TRANSPORT_STATE_ACTIVE };
struct impl { void *log; } backend;
struct spa_bt_monitor { void *log; } monitor;
struct transport_data { int err; bool requesting; } td;
struct spa_bt_transport {
    void *backend, *user_data;
    struct spa_bt_monitor *monitor;
    int fd, state, acquire_refcount, error_count;
    bool acquired;
    uint64_t last_error_time;
};
#define SPA_CONTAINER_OF(p, type, member) ((type *)(p))
#define spa_log_debug(...) ((void)0)
#define spa_assert assert
#define TRANSPORT_ERROR_TIMEOUT 6000000000ULL
#define TRANSPORT_ERROR_MAX_RETRY 3
#define spa_bt_transport_impl(t, op, version, optional) sco_acquire_cb(t, optional)
static int error_events, connect_result, connect_error;
static uint64_t get_time_now(struct spa_bt_monitor *m) { return 10000000000ULL; }
static void spa_bt_transport_emit_state_changed(struct spa_bt_transport *t, int old, int state) {
    if (state == SPA_BT_TRANSPORT_STATE_ERROR) ++error_events;
}
static void spa_bt_transport_set_state(struct spa_bt_transport *t, int state) {
    int old = t->state;
    if (old != state) {
        t->state = state;
        spa_bt_transport_emit_state_changed(t, old, state);
    }
}
static int sco_do_connect(struct spa_bt_transport *t) {
    td.err = connect_error;
    return connect_result;
}
static void sco_start_source(struct spa_bt_transport *t) {}
static void sco_ready(struct spa_bt_transport *t) {
    td.requesting = false;
    spa_bt_transport_set_state(t, td.err ? SPA_BT_TRANSPORT_STATE_ERROR : SPA_BT_TRANSPORT_STATE_ACTIVE);
}
'''
tests = r'''
static struct spa_bt_transport fresh(int state) {
    td = (struct transport_data){0};
    error_events = 0;
    connect_result = 42;
    connect_error = -EINPROGRESS;
    return (struct spa_bt_transport){ .backend=&backend, .user_data=&td,
        .monitor=&monitor, .fd=-1, .state=state };
}
int main(void) {
    for (int initial = SPA_BT_TRANSPORT_STATE_ERROR; initial <= SPA_BT_TRANSPORT_STATE_IDLE; ++initial) {
        struct spa_bt_transport t = fresh(initial);
        assert(spa_bt_transport_acquire(&t, false) == 0);
        if (t.state != SPA_BT_TRANSPORT_STATE_PENDING) {
            fprintf(stderr, "FAIL: asynchronous acquire retained state %d (initial %d)\n", t.state, initial);
            return 1;
        }
        assert(td.requesting && t.acquire_refcount == 1 && t.acquired);
        assert(spa_bt_transport_acquire(&t, false) == 0);
        assert(t.acquire_refcount == 2 && !error_events);
        assert(t.state != SPA_BT_TRANSPORT_STATE_ACTIVE);
        td.err = 0;
        sco_ready(&t);
        assert(t.state == SPA_BT_TRANSPORT_STATE_ACTIVE);
    }
    struct spa_bt_transport t = fresh(SPA_BT_TRANSPORT_STATE_IDLE);
    connect_result = -1;
    assert(spa_bt_transport_acquire(&t, false) < 0);
    assert(t.state == SPA_BT_TRANSPORT_STATE_ERROR && !t.acquired && error_events == 1);
    t = fresh(SPA_BT_TRANSPORT_STATE_IDLE);
    t.fd = 42;
    assert(spa_bt_transport_acquire(&t, true) == 0);
    assert(t.state == SPA_BT_TRANSPORT_STATE_ACTIVE && !error_events);
    t = fresh(SPA_BT_TRANSPORT_STATE_ERROR);
    assert(spa_bt_transport_acquire(&t, false) == 0);
    td.err = -ECONNREFUSED;
    sco_ready(&t);
    assert(t.state == SPA_BT_TRANSPORT_STATE_ERROR && error_events == 1);
    puts("PASS: cold/retry concurrent acquire, delayed readiness, synchronous success, real failures");
}
'''
source = stub + function(sys.argv[1], 'static int sco_acquire_cb(void *data, bool optional)')
source += function(sys.argv[2], 'int spa_bt_transport_acquire(struct spa_bt_transport *transport, bool optional)')
source += tests
with tempfile.TemporaryDirectory(prefix='stt-sco-unit-') as tmp:
    binary = str(pathlib.Path(tmp) / 'test')
    subprocess.run(['cc', '-std=c11', '-Wall', '-Wno-unused-variable', '-Wno-unused-parameter',
                    '-x', 'c', '-', '-o', binary], input=source, text=True, check=True)
    sys.exit(subprocess.run([binary]).returncode)
