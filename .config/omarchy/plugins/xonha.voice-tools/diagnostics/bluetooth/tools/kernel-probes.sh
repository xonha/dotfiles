#!/bin/bash
# Install (or with "off": remove) the tracefs kprobes and dynamic-debug prints used to trace
# Bluetooth SCO setup through the kernel and btusb. Needs passwordless sudo.
S=/sys/kernel/tracing
if [ "${1:-}" = off ]; then
  sudo -n sh -c "echo 0 > $S/events/bt/enable; echo > $S/kprobe_events; echo > $S/trace
    echo 'module btusb -p' > /sys/kernel/debug/dynamic_debug/control
    echo 'func hci_sync_conn_complete_evt -p' > /sys/kernel/debug/dynamic_debug/control"
  exit
fi
sudo -n sh -c "
echo 0 > $S/events/bt/enable 2>/dev/null
echo > $S/kprobe_events
echo 'p:bt/notify btusb_notify evt=\$arg2:u32' >> $S/kprobe_events
echo 'p:bt/work btusb_work' >> $S/kprobe_events
echo 'p:bt/switch_alt btusb_switch_alt_setting new_alts=\$arg2:s32' >> $S/kprobe_events
echo 'r:bt/switch_alt_ret btusb_switch_alt_setting ret=\$retval:s32' >> $S/kprobe_events
echo 'p:bt/set_intf usb_set_interface ifnum=\$arg2:s32 alt=\$arg3:s32' >> $S/kprobe_events
echo 'r:bt/set_intf_ret usb_set_interface ret=\$retval:s32' >> $S/kprobe_events
echo 'r:bt/submit_isoc_ret btusb_submit_isoc_urb ret=\$retval:s32' >> $S/kprobe_events
echo 'r:bt/autopm_ret usb_autopm_get_interface ret=\$retval:s32' >> $S/kprobe_events
echo 'p:bt/conn_add hci_conn_add_unset type=\$arg2:s32' >> $S/kprobe_events
echo 'p:bt/conn_del hci_conn_del' >> $S/kprobe_events
echo 'p:bt/conn_failed hci_conn_failed status=\$arg2:u8' >> $S/kprobe_events
echo 'p:bt/conn_complete hci_conn_complete_evt status=+0(\$arg2):u8 link_type=+9(\$arg2):u8' >> $S/kprobe_events
echo 'p:bt/disconn_complete hci_disconn_complete_evt status=+0(\$arg2):u8 handle=+1(\$arg2):u16 reason=+3(\$arg2):u8' >> $S/kprobe_events
echo 'p:bt/mode_change hci_mode_change_evt status=+0(\$arg2):u8' >> $S/kprobe_events
echo 'p:bt/sco_setup hci_sco_setup status=\$arg2:u8' >> $S/kprobe_events
echo 'p:bt/cs_enh_setup_sync hci_cs_enhanced_setup_sync_conn status=\$arg2:u8' >> $S/kprobe_events
echo 'p:bt/sync_complete hci_sync_conn_complete_evt' >> $S/kprobe_events
echo 'p:bt/connect_cfm sco_connect_cfm status=\$arg2:u8' >> $S/kprobe_events
echo 'p:bt/sco_tx hci_send_sco' >> $S/kprobe_events
echo 'p:bt/sco_rx_urb btusb_isoc_complete' >> $S/kprobe_events
echo 1 > $S/events/bt/enable
echo 'module btusb +pf' > /sys/kernel/debug/dynamic_debug/control
echo 'func hci_sync_conn_complete_evt +pf' > /sys/kernel/debug/dynamic_debug/control
echo > $S/trace
echo 1 > $S/tracing_on"
