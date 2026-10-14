#!/usr/bin/env python3
"""Inspect, enroll, or verify fingerprints on a named fprintd reader."""

import argparse
import json
import sys

from gi.repository import Gio, GLib


BUS_NAME = "net.reactivated.Fprint"
MANAGER_PATH = "/net/reactivated/Fprint/Manager"
MANAGER_INTERFACE = "net.reactivated.Fprint.Manager"
DEVICE_INTERFACE = "net.reactivated.Fprint.Device"
FLAGS = Gio.DBusCallFlags.ALLOW_INTERACTIVE_AUTHORIZATION
READER_NAMES = {"chipsailing": "Chipsailing", "synaptics": "Synaptics"}


def call(proxy, method, parameters=None):
    return proxy.call_sync(method, parameters, FLAGS, -1, None)


def cleanup_call(device, method):
    try:
        call(device, method)
    except GLib.Error as error:
        # A disconnected USB reader cannot be stopped or released. Preserve the
        # enrollment/verification result instead of replacing it with this error.
        if not any(
            message in str(error).lower()
            for message in ("removed from the system", "no such device")
        ):
            raise


def proxy_for(connection, path, interface):
    return Gio.DBusProxy.new_sync(
        connection, Gio.DBusProxyFlags.NONE, None, BUS_NAME, path, interface, None
    )


def devices(connection):
    manager = proxy_for(connection, MANAGER_PATH, MANAGER_INTERFACE)
    paths = call(manager, "GetDevices").unpack()[0]
    for path in paths:
        device = proxy_for(connection, path, DEVICE_INTERFACE)
        yield path, device.get_cached_property("name").unpack(), device


def select_device(connection, reader):
    matches = [
        (path, name, device)
        for path, name, device in devices(connection)
        if READER_NAMES[reader].lower() in name.lower()
    ]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one {reader} reader; found {len(matches)}")
    return matches[0]


def enrolled_fingers(device):
    try:
        return call(device, "ListEnrolledFingers", GLib.Variant("(s)", ("",))).unpack()[0]
    except GLib.Error as error:
        if "NoEnrolledPrints" not in error.message:
            raise
        return []


def status_data(connection):
    readers = []
    for path, name, device in devices(connection):
        reader = next(
            (key for key, label in READER_NAMES.items() if label.lower() in name.lower()),
            "other",
        )
        fingers = enrolled_fingers(device)
        readers.append(
            {
                "reader": reader,
                "name": name,
                "path": path,
                "fingers": fingers,
                "count": len(fingers),
                "stages": device.get_cached_property("num-enroll-stages").unpack(),
            }
        )

    # pam_fprintd 1.94.5 chooses the connected device with the most prints.
    preferred = max(readers, key=lambda item: item["count"], default=None)
    return {
        "readers": readers,
        "preferred": preferred["reader"] if preferred and preferred["count"] else None,
    }


def run_action(device, action, finger):
    call(device, "Claim", GLib.Variant("(s)", ("",)))
    started = False
    try:
        if action == "probe":
            print("Reader claimed successfully.")
            return True

        if action == "enroll":
            enrolled = enrolled_fingers(device)
            if finger in enrolled:
                raise RuntimeError(f"{finger} is already enrolled on this reader")

        loop = GLib.MainLoop()
        result = {"name": None, "stages": 0}
        total = device.get_cached_property("num-enroll-stages").unpack()
        signal_name = "EnrollStatus" if action == "enroll" else "VerifyStatus"

        def on_signal(_proxy, _sender, name, parameters):
            if name != signal_name:
                return
            status, done = parameters.unpack()
            if action == "enroll" and status == "enroll-stage-passed":
                result["stages"] += 1
                print(f"Stage {result['stages']}/{total} accepted. Lift and reposition your finger.", flush=True)
            else:
                print(status, flush=True)
            if done:
                result["name"] = status
                loop.quit()

        handler = device.connect("g-signal", on_signal)
        try:
            method = "EnrollStart" if action == "enroll" else "VerifyStart"
            target = finger if action == "enroll" else "any"
            call(device, method, GLib.Variant("(s)", (target,)))
            started = True
            print("Touch the selected reader when prompted.", flush=True)
            loop.run()
        finally:
            device.disconnect(handler)
            if started:
                method = "EnrollStop" if action == "enroll" else "VerifyStop"
                cleanup_call(device, method)

        expected = "enroll-completed" if action == "enroll" else "verify-match"
        if result["name"] in ("enroll-disconnected", "verify-disconnected"):
            print(
                "Reader disconnected during the scan. Try a direct USB port "
                "instead of a hub, then retry.",
                file=sys.stderr,
            )
        return result["name"] == expected
    finally:
        cleanup_call(device, "Release")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("list", "status", "probe", "enroll", "verify"))
    parser.add_argument("--reader", choices=READER_NAMES, default="chipsailing")
    parser.add_argument("--finger", default="right-index-finger")
    args = parser.parse_args()

    try:
        connection = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        if args.action == "list":
            for path, name, _device in devices(connection):
                print(f"{path}: {name}")
            return 0
        if args.action == "status":
            print(json.dumps(status_data(connection), ensure_ascii=False))
            return 0
        path, name, device = select_device(connection, args.reader)
        print(f"Using {name} at {path}", flush=True)
        return 0 if run_action(device, args.action, args.finger) else 1
    except (GLib.Error, RuntimeError) as error:
        print(f"Fingerprint operation failed: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nFingerprint operation cancelled.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
