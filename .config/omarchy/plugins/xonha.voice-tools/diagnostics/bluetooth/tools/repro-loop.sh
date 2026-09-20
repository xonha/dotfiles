#!/bin/bash
# Restart WirePlumber, run a traced trial, stop when the kernel logs submission failed (90).
SC=$(dirname "$0")
for i in 1 2 3 4 5 6; do
  systemctl --user restart wireplumber; sleep 9
  /home/tank/repos/speech-to-text/bin/stt status --json | grep -q '"state": *"idle"' || { echo "stt busy"; break; }
  T0=$(date +%s)
  "$SC/trial.sh" "repro-$i" > "$SC/repro-$i.log" 2>&1
  if sudo -n journalctl -k --since "@$T0" --no-pager | grep -q 'submission failed (90)'; then echo "REPRODUCED on attempt $i"; exit 0; fi
  echo "attempt $i: no failure"; sleep 3
done
echo "not reproduced"
