#!/bin/bash
# Reboots when installed updates are not running yet: /run/reboot-required
# (kernel, libc and similar), or a QEMU process that still maps a binary or
# library apt has replaced, since running VMs only pick up QEMU fixes on restart.
set -euo pipefail

reason=""
if [[ -f /run/reboot-required ]]; then
  reason="reboot-required by $(tr '\n' ' ' < /run/reboot-required.pkgs 2>/dev/null || true)"
else
  for pid in $(pgrep -f '^/usr/bin/qemu-system' || true); do
    if grep -qE ' /usr/\S+ \(deleted\)$' "/proc/$pid/maps" 2>/dev/null; then
      reason="QEMU pid $pid runs a replaced binary or library"
      break
    fi
  done
fi

if [[ -z $reason ]]; then
  echo "No reboot needed"
  exit 0
fi

echo "Rebooting: $reason"
systemctl reboot
