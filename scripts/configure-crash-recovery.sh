#!/bin/bash
# Make host crashes recover on their own and leave evidence behind.
#
# The host is the only always-on machine, so crash evidence has to survive
# on the host itself and it has to reboot without someone pulling the power.
#
#   1. crash_kexec_post_notifiers=1: on a kernel panic, the panic message is
#      written to EFI pstore before kdump runs. systemd-pstore copies it to
#      /var/lib/systemd/pstore on the next boot, even if kdump fails.
#   2. kernel.hung_task_panic=1: a task stuck in disk I/O for 120s panics the
#      kernel, so a stalled SSD turns into a logged panic and a reboot
#      instead of a frozen host.
#   3. sp5100_tco: loads the AMD FCH hardware watchdog so the RuntimeWatchdogSec
#      in /etc/systemd/system.conf.d/watchdog.conf resets a fully frozen host.
#      Ubuntu blacklists the module from auto-loading.
#   4. SATA link power management set to max_performance, so the SSD link
#      never enters low-power states.
#
# Items 2-4 apply immediately. Item 1 needs a reboot.

set -euo pipefail

echo "Adding crash_kexec_post_notifiers=1 to the kernel command line..."
sudo tee /etc/default/grub.d/90-crash-capture.cfg > /dev/null << 'EOF'
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT crash_kexec_post_notifiers=1"
EOF
sudo update-grub

echo "Panicking on tasks hung in I/O..."
sudo tee /etc/sysctl.d/91-hung-task-panic.conf > /dev/null << 'EOF'
kernel.hung_task_panic = 1
kernel.hung_task_timeout_secs = 120
EOF
sudo sysctl -p /etc/sysctl.d/91-hung-task-panic.conf

echo "Loading the sp5100_tco hardware watchdog..."
echo sp5100_tco | sudo tee /etc/modules-load.d/sp5100_tco.conf > /dev/null
sudo modprobe sp5100_tco
if ls /dev/watchdog* > /dev/null 2>&1; then
  # Re-exec systemd so it opens the watchdog device now.
  sudo systemctl daemon-reexec
else
  echo "WARNING: sp5100_tco loaded but no /dev/watchdog appeared; the BIOS may disable the TCO timer."
fi

echo "Setting SATA link power management to max_performance..."
sudo tee /etc/udev/rules.d/90-sata-lpm.rules > /dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="max_performance"
EOF
# Dummy and empty ports reject the setting, so skip them.
for policy in /sys/class/scsi_host/host*/link_power_management_policy; do
  echo max_performance | sudo tee "$policy" > /dev/null 2>&1 || echo "  skipped $policy (not supported)"
done

echo ""
echo "Current state:"
echo "  hung_task_panic:  $(cat /proc/sys/kernel/hung_task_panic)"
echo "  watchdog devices: $(ls /dev/watchdog* 2>/dev/null | tr '\n' ' ')"
echo "  systemd watchdog: $(systemctl show -p WatchdogDevice -p RuntimeWatchdogUSec | tr '\n' ' ')"
echo "  SATA LPM:         $(cat /sys/class/scsi_host/host*/link_power_management_policy | sort -u | tr '\n' ' ')"
echo "  post notifiers:   $(cat /sys/module/kernel/parameters/crash_kexec_post_notifiers) (Y after reboot)"
echo ""
echo "Reboot to apply the kernel command line: sudo reboot"
echo ""
echo "After the next crash, check:"
echo "  sudo ls -la /var/lib/systemd/pstore /var/crash"
echo "  journalctl -b -1 -k | grep -iE 'hung|panic|blocked for more than'"
