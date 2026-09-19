#!/bin/bash
# One dictation startup trial: kernel probes + btmon + userspace timing. $1 = label
set -u
SC=$(dirname "$0"); L=${1:-trial}; S=/sys/kernel/tracing
sudo -n sh -c "echo > $S/trace"
sudo -n btmon -w "$SC/$L.btsnoop" >/dev/null 2>&1 &
BTMON=$!
sleep 0.5
T0=$(date +%s.%N)
echo "T0 unix $T0  monotonic $(python3 -c 'import time;print(round(time.monotonic(),3))')"
python3 /tmp/stt-startup-trace.py 2>&1 | grep -vE '"graph"|audio-progress'
sleep 0.5
sudo -n kill $BTMON; wait $BTMON 2>/dev/null
echo "--- ftrace"
sudo -n cat $S/trace | grep -v '^#' | grep -vE 'sco_tx|sco_rx_urb' | sed -E 's/^ +//; s/ \[[0-9]+\] [^ ]+ / /; s/\([^)]*\)//' | cut -c1-120
echo "--- sco tx/rx-urb per second"
sudo -n cat $S/trace | grep -E 'sco_tx|sco_rx_urb' | sed -E 's/.* ([0-9]+)\.[0-9]+: (sco_tx|sco_rx_urb).*/\1 \2/' | sort | uniq -c | tr '\n' ';'; echo
echo "--- dmesg"
sudo -n journalctl -k -o short-precise --since "@${T0%.*}" --no-pager | grep -E 'Bluetooth:|hci_sync_conn|hci_conn_request|btusb_notify|__set_isoc|btusb_submit_isoc|__fill_isoc' | cut -c1-160
echo "--- btmon (commands/events only)"
sudo -n chown $USER "$SC/$L.btsnoop"
btmon -r "$SC/$L.btsnoop" -t 2>/dev/null | grep -E '^[<>] HCI (Command|Event)|^\s+(Status|Handle|Link type|Air mode|Reason|Opcode|Voice setting|Transmit coding|Receive coding|RX packet length|TX packet length|Mode|Interval|Packet type|Retransmission|Max latency|Transmit bandwidth|Receive bandwidth):' | grep -vE 'HCI Event: Number of Completed|HCI Event: Command Complete.*(Read RSSI|Read Clock)|Vendor' | sed -E 's/\{[^}]*\}//' | cut -c1-140
