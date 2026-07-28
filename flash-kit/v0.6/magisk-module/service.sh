#!/system/bin/sh
# S688LN WiFi+BT fix v0.6 - late_start retry + status log.
# If post-fs-data missed anything (timing), retry once after boot completes.
MODDIR=${0%/*}
LOG="$MODDIR/last-run.log"

n=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$n" -lt 60 ]; do
    sleep 2
    n=$((n+1))
done

{
echo "== s688ln_wifi_fix service.sh (boot_completed) $(date) =="
if ! grep -q '^rfkill ' /proc/modules; then
    insmod "$MODDIR/gki/rfkill.ko" && echo "OK rfkill (retry)" || echo "FAIL rfkill (retry)"
fi
for m in cfg80211 sprd_wlan_combo sprdbt_tty; do
    grep -q "^$m " /proc/modules && continue
    ko=$(find /vendor_dlkm/lib/modules /vendor/lib/modules -name "$m.ko" 2>/dev/null | head -1)
    [ -n "$ko" ] && { insmod "$ko" && echo "OK $m (retry)" || echo "FAIL $m (retry)"; }
done
echo "-- final module state --"
grep -E '^(rfkill|cfg80211|sprd_wlan_combo|sprdbt_tty|mii|usbnet) ' /proc/modules
echo "== service.sh done =="
} >> "$LOG" 2>&1
exit 0
