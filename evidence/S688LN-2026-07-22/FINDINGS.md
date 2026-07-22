# S688LN kernel evidence — 2026-07-22 (why v0.1 killed WiFi, and the v0.2 fix)

Read-only evidence pulled from the device on stock (`GATHER-INFO.bat`).

## Stock kernel identity (VERIFIED, from on-device `uname -a`)
```
6.6.102-android15-8-g1481f357a31c-ab14794947-4k #1 SMP PREEMPT Wed Jan 28 17:42:19 UTC 2026 aarch64
```
- VERSION.SUBLEVEL: **6.6.102**
- KMI generation: **android15-8**
- ACK common SHA: **1481f357a31c**
- Android build number: **ab14794947**
- LOCALVERSION: **-4k** (`CONFIG_ARM64_4K_PAGES=y`)
- Toolchain: clang 18 / LLD 18, `CONFIG_LTO_NONE=y`

## WiFi stack (VERIFIED)
WiFi = Unisoc WCN combo, shipped as **vendor prebuilt modules in `/vendor_dlkm`**:
- `sprd_wlan_combo.ko` (618 KB loaded) → depends on
- `cfg80211.ko` (Unisoc's own fork; note **`# CONFIG_CFG80211 is not set`** in the GKI config — the in-tree cfg80211 is disabled and Unisoc ships their own) → and
- `unisoc_wcn_bsp.ko` (bt/fm/gnss/wlan bus), pulling in `sipc_core`, `sdhci_sprd`, etc.

## Root cause of the v0.1 WiFi failure (VERIFIED reasoning)
- v0.1 built ACK **tip = 6.6.139**, not the stock sublevel.
- The phone **booted and the display worked** → the vermagic *flag-tail* (SMP/PREEMPT/arch) matched and most vendor `.ko`s loaded (247 modules on stock).
- But with `CONFIG_MODVERSIONS=y`, `same_magic()` **skips the UTS_RELEASE token** and enforces **per-exported-symbol CRCs**. Between 6.6.102 and 6.6.139 at least one symbol used by the WCN/wlan chain changed CRC → those modules were **rejected** → WiFi could never turn on.

## The v0.2 fix
Pin `common/` to the **exact stock SHA `1481f357a31c`** so every exported-symbol CRC is byte-identical to stock → the unmodified stock vendor `.ko`s load → WiFi works.
- `stock` profile: pure reproduction, highest confidence.
- `safe` profile: config-only tuning (TCP bbr, zram zstd) on the same SHA — no struct/LTO change, so CRCs stay identical → still WiFi-safe.
- `aggressive` profile: ThinLTO + debug strip **changes CRCs** → will re-break WiFi. **Do not flash aggressive.**

Set `BUILD_NUMBER=14794947` to reproduce the `-ab…` tail (cosmetic; MODVERSIONS ignores it for loading).

Files here: `kernel_evidence.txt` (uname/modules/sys), `ko_list.txt` (vendor module inventory), `stock_config.gz` (`/proc/config.gz`), `cmdline.txt`, `props.txt`. Full `dmesg.txt`/`logcat_tail.txt` kept locally (too large to commit).
