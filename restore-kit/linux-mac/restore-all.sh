#!/usr/bin/env bash
# S688LN system-app restore kit - Linux/macOS version.
# Requires your own adb on PATH (platform-tools). No root needed for the
# core restore; the Magisk step needs root.
#
#   ./restore-all.sh scan      # read-only report
#   ./restore-all.sh restore   # re-enable + re-install hidden system apps
#   ./restore-all.sh verify    # read-only confirmation
#   ./restore-all.sh modules   # list Magisk modules (root) to spot a debloater
set -euo pipefail
USER_ID="${USER_ID:-0}"
CMD="${1:-scan}"

need_device() {
  command -v adb >/dev/null || { echo "adb not found on PATH"; exit 1; }
  echo "Waiting for device..."; adb wait-for-device
  local m; m=$(adb shell getprop ro.product.model | tr -d '\r')
  echo "Device: $m"
  [[ "$m" == *S688LN* ]] || echo "WARN: kit built for itel S688LN; detected $m (commands are still safe/generic)."
}

case "$CMD" in
  scan)
    need_device
    inst=$(adb shell "pm list packages -s | cut -d: -f2" | tr -d '\r' | sort)
    all=$(adb shell "cmd package list packages -u -s | cut -d: -f2" | tr -d '\r' | sort)
    dis=$(adb shell "pm list packages -d | cut -d: -f2" | tr -d '\r' | sort)
    hidden=$(comm -13 <(printf '%s\n' "$inst") <(printf '%s\n' "$all"))
    echo "Installed system apps : $(printf '%s\n' "$inst" | grep -c . || true)"
    echo "Hidden (to restore)   : $(printf '%s\n' "$hidden" | grep -c . || true)"
    echo "Disabled (to enable)  : $(printf '%s\n' "$dis" | grep -c . || true)"
    echo "--- hidden ---"; printf '%s\n' "$hidden"
    echo "--- disabled ---"; printf '%s\n' "$dis"
    ;;
  restore)
    need_device
    echo "Re-enabling disabled apps..."
    adb shell "for p in \$(pm list packages -d | cut -d: -f2); do pm enable \$p >/dev/null 2>&1 && echo enabled:\$p; done"
    echo "Re-installing hidden system apps..."
    adb shell "for p in \$(cmd package list packages -u -s | cut -d: -f2); do cmd package install-existing --user ${USER_ID} \$p 2>/dev/null | grep -qi installed && echo ok:\$p; done"
    echo "Done. Reboot the phone: adb reboot"
    ;;
  verify)
    need_device
    inst=$(adb shell "pm list packages -s | cut -d: -f2" | tr -d '\r' | sort)
    all=$(adb shell "cmd package list packages -u -s | cut -d: -f2" | tr -d '\r' | sort)
    dis=$(adb shell "pm list packages -d | cut -d: -f2" | tr -d '\r' | sort)
    hidden=$(comm -13 <(printf '%s\n' "$inst") <(printf '%s\n' "$all"))
    nh=$(printf '%s\n' "$hidden" | grep -c . || true)
    nd=$(printf '%s\n' "$dis" | grep -c . || true)
    echo "Still hidden: $nh | Still disabled: $nd"
    { [[ "$nh" -eq 0 && "$nd" -eq 0 ]] && echo "OK - all restored."; } || echo "Some remain -> likely a Magisk debloat module. Run: ./restore-all.sh modules"
    ;;
  modules)
    need_device
    adb shell "su -c 'for m in /data/adb/modules/*/; do n=\$(basename \$m); st=enabled; [ -f \${m}disable ] && st=DISABLED; nm=\$(grep -m1 ^name= \${m}module.prop 2>/dev/null | cut -d= -f2); echo \"\$n [\$st] \$nm\"; done'"
    echo "To disable one: adb shell \"su -c 'touch /data/adb/modules/<folder>/disable'\" ; then adb reboot"
    ;;
  *)
    echo "usage: $0 {scan|restore|verify|modules}"; exit 1 ;;
esac
