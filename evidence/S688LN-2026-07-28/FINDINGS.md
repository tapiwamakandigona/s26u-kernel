# S688LN 2026-07-28 — WiFi/BT SOLVED on a custom-built GKI kernel (v0.6)

**Outcome: SUCCESS, VERIFIED.** WiFi and Bluetooth fully working on a
self-built GKI kernel (release `v0.6-stock-run30394576840`). This closes the
"custom kernel kills WiFi/BT" saga that started with v0.1 and was twice
declared a factory-binary wall. It was not a wall — it was **two stacked
root causes**, each masking the next.

## The three-layer onion (why this took four kernels)

### Layer 1 — symbol-CRC drift (v0.1, solved in v0.2)
v0.1 built ACK tip (6.6.139) instead of the stock commit. With
`MODVERSIONS=y` the loader checks per-symbol CRCs, so the Unisoc vendor
modules (`sprd_wlan_combo` → `cfg80211` → `unisoc_wcn_bsp`) refused to load.
**Fix:** pin `common/` to the exact stock commit `1481f357a31c`.

### Layer 2 — missing release stamp (v0.2.1 + v0.4, found 2026-07-28, solved in v0.5)
Both "exact-source" kernels booted with uname
`6.6.102-android15-8-maybe-dirty-4k` because Kleaf ran **without
`--config=stamp` / `BUILD_NUMBER`**. Nothing crashed — but the 14 on-demand
WiFi/BT modules were never even *attempted* (zero log lines), which is what
made it look like a mysterious vendor wall.
**Fix (v0.5):** `--config=stamp` + `BUILD_NUMBER=14794947` + a hard CI gate
that fails the build unless the release string is byte-identical to stock:
`6.6.102-android15-8-g1481f357a31c-ab14794947-4k`.

### Layer 3 — GKI protected exports + per-build module signing (found by v0.5, solved by v0.6)
With the exact uname, the loader finally *found and attempted*
`/system_dlkm/lib/modules/rfkill.ko` (note: that dir is **flat**, not
uname-keyed — the earlier folder-name theory was wrong; the uname mattered
for the *attempt*, not the path). Result:

```
rfkill: exports protected symbol rfkill_alloc
insmod rfkill.ko -> EPERM
cfg80211 / sprdbt_tty / sprd_wlan_combo -> Unknown symbol cascade
```

The stock `rfkill.ko` is signed with **Google's per-build key**. A rebuilt
kernel trusts only **its own** build key. An untrusted module may *import*
GKI-protected symbols but may not **export** them — and `rfkill` exports
`rfkill_alloc` etc. One rejected keystone module → all 14 WiFi/BT modules
dead (`stock lsmod: rfkill 36864 2 sprdbt_tty,cfg80211`).

**Fix (v0.6):** ship the **same CI run's own signed** `rfkill.ko` (+ the
usbnet family for completeness) and insmod them at `post-fs-data` via a tiny
Magisk module (`s688ln_wifi_fix`), *before* the WiFi/BT services come up.
The modules MUST come from the same run as the Image — every build generates
a fresh signing key, so kos from any other build are untrusted.

## v0.6 verification (on-device STEP-3 evidence, this directory)

| Check | Result |
|---|---|
| Kernel accepted OUR signed rfkill.ko | `OK rfkill (build-matched signed)` in `fix_module_log.txt` — impossible on the stock kernel, which doesn't trust our key. Proves the running kernel is ours. |
| Full chain loaded | `rfkill 36864 2 sprdbt_tty,cfg80211`; `cfg80211 1114112 1 sprd_wlan_combo`; usbnet family live (`lsmod.txt`) |
| Module count | **248 = exactly stock** (v0.5 had 234) |
| dmesg | zero `EPERM` / `protected symbol` lines |
| WiFi | `wlan0 state UP`, framework `state: CONNECTED/CONNECTED` (`wlan0_state.txt`) |
| Bluetooth | switch on, `sprdbt_tty` loaded and in use |
| Owner report | "wifi and bluetooth are working" (2026-07-28 21:30) |

## The working recipe (reproduce from scratch)

1. Pin ACK `common/` to the stock SHA (`1481f357a31c`), stock GKI config, `LTO_NONE`, `MODVERSIONS=y`.
2. Build with Kleaf using `--config=stamp` and stock `BUILD_NUMBER` (`14794947`); **gate** on the release string being byte-identical to stock.
3. Collect the build's **own signed** `rfkill.ko` + usbnet family from the same run; **gate** on vermagic match + "Module signature appended".
4. Package: boot.img (stock 67108864-byte layout) + Magisk module that insmods `gki/rfkill.ko` then the vendor chain (`cfg80211` → `sprd_wlan_combo` → `sprdbt_tty`) at post-fs-data, skipping everything if `rfkill` is already loaded (stock-kernel no-op guard).
5. Flash boot via **fastbootd only** (bootloader fastboot is non-functional on this unit).

## Corrections to earlier conclusions
- **"Unisoc WCN only accepts the factory kernel binary" (2026-07-22) — REFUTED.** It accepts any kernel; the modules just need a trusted signature (or must not need to export protected symbols).
- **"system_dlkm modules live in a uname-keyed folder" — REFUTED** on this device: the dir is flat. The stamp still mattered (Layer 2), just not via the folder name.
- The WCN chip/firmware were never the problem — firmware download and chipid readback worked on every kernel.
