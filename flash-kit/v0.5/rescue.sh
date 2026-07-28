#!/system/bin/sh
# S688LN v0.5 rescue: if the WiFi/BT modules were not auto-loaded,
# load them manually by ABSOLUTE PATH (bypasses any name/version lookup).
# Safe: only loads the same stock vendor modules the phone always uses.
echo "== rescue.sh start =="
echo "kernel: $(uname -r)"

load_mod() {
    name="$1"
    if grep -q "^$name " /proc/modules 2>/dev/null; then
        echo "SKIP $name already loaded"
        return 0
    fi
    ko=$(find /system_dlkm/lib/modules /vendor_dlkm/lib/modules /vendor/lib/modules /odm/lib/modules -name "$name.ko" 2>/dev/null | head -1)
    if [ -z "$ko" ]; then
        echo "MISS $name.ko not found on any partition"
        return 1
    fi
    echo "LOAD $ko"
    insmod "$ko" && echo "OK   $name" || echo "FAIL $name"
}

# dependency order: rfkill -> cfg80211 -> sprd_wlan_combo ; sprdbt_tty needs rfkill
load_mod rfkill
load_mod cfg80211
load_mod sprd_wlan_combo
load_mod sprdbt_tty
load_mod mii
load_mod usbnet

echo "== modules after rescue =="
grep -E '^(rfkill|cfg80211|sprd_wlan_combo|sprdbt_tty|usbnet|mii) ' /proc/modules

echo "== switching WiFi on =="
svc wifi enable
sleep 6
echo "wifi_on setting: $(settings get global wifi_on)"
ip link show wlan0 2>&1

echo "== switching Bluetooth on =="
svc bluetooth enable 2>&1
sleep 4
echo "bluetooth_on setting: $(settings get global bluetooth_on)"

echo "== rescue.sh done =="
