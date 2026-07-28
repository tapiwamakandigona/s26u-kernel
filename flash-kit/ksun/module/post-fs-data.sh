#!/system/bin/sh
# S688LN WiFi+BT fix v0.6 - post-fs-data stage (runs early, before HALs).
# On the STOCK kernel rfkill is already loaded by init -> we do nothing.
# On the custom exact-stamp kernel the Google-signed rfkill.ko is rejected
# ("exports protected symbol"), so we load OUR build-matched signed copy,
# then the vendor WiFi/BT chain, exactly like stock boot would have.
MODDIR=${0%/*}
LOG="$MODDIR/last-run.log"
{
echo "== s688ln_wifi_fix post-fs-data $(date) =="
echo "kernel: $(uname -r)"

if grep -q '^rfkill ' /proc/modules; then
    echo "rfkill already loaded (stock kernel or already fixed) - nothing to do."
    exit 0
fi

insmod "$MODDIR/gki/rfkill.ko" && echo "OK rfkill (build-matched signed)" || echo "FAIL rfkill"

# Vendor chain, dependency order. Absolute paths, same as stock loading.
for m in cfg80211 sprd_wlan_combo sprdbt_tty; do
    if grep -q "^$m " /proc/modules; then
        echo "SKIP $m already loaded"
        continue
    fi
    ko=$(find /vendor_dlkm/lib/modules /vendor/lib/modules -name "$m.ko" 2>/dev/null | head -1)
    if [ -z "$ko" ]; then
        echo "MISS $m.ko not found"
        continue
    fi
    insmod "$ko" && echo "OK $m ($ko)" || echo "FAIL $m ($ko)"
done

# Optional GKI USB-network helpers (USB tethering adapters). Best effort.
for m in mii usbnet asix ax88179_178a cdc_ether cdc_eem cdc_ncm r8152 r8153_ecm aqc111; do
    grep -q "^$m " /proc/modules && continue
    [ -f "$MODDIR/gki/$m.ko" ] || continue
    insmod "$MODDIR/gki/$m.ko" && echo "OK $m" || echo "note: $m did not load (non-critical)"
done

echo "== done =="
} > "$LOG" 2>&1
exit 0
