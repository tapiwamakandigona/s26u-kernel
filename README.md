# S26U GKI kernel CI

> **PROJECT PARKED — 2026-07-22.** v0.2.1 (exact stock source pin
> `1481f357a31c` / ab14794947, verified checkout, stock profile) flashed OK and
> booted, but **WiFi and Bluetooth still failed to come up** — identical symptom
> to v0.1 (toggle flips back off; BT reports on but is off). Conclusion: the
> Unisoc WCN vendor stack only accepts the *factory-built kernel binary*; even a
> byte-faithful source rebuild is rejected (suspected: CRC/genksyms or module
> signing divergence in Google's official build environment that we cannot
> reproduce). Device restored to stock via UNDO-FASTBOOTD (root intact). No
> further kernel builds should be flashed. Post-mortem:
> `evidence/S688LN-2026-07-22/FINDINGS.md`. The de-skin ladder continues via
> Magisk modules on the stock kernel.

Free-runner CI that builds a custom **GKI kernel** for the **itel S26 Ultra**
(S688LN · Unisoc T7300 · ums9360 · Android 15). Actions is billing-blocked on the
private dev repo, so the build lives here on a public repo where GitHub runners are
free (same pattern as the PodEQ mirror).

Device stock kernel (VERIFIED from on-device evidence 2026-07-22):
`6.6.102-android15-8-g1481f357a31c-ab14794947-4k` GKI, clang 18 / kleaf,
`LTO_NONE`, `MODVERSIONS=y`, default TCP `cubic`, zram `lzo-rle`.

## v0.2 — the WiFi fix (why v0.1 broke it)
v0.1 built ACK **tip (6.6.139)**. The phone booted and display worked (vermagic
flag-tail matched), but the Unisoc **WCN/wlan** vendor modules
(`sprd_wlan_combo` → `cfg80211` → `unisoc_wcn_bsp`) were rejected on **symbol-CRC
drift** between 6.6.102 and 6.6.139 → WiFi never came up. With `MODVERSIONS`, the
loader ignores `UTS_RELEASE` and only checks per-symbol CRCs, so the fix is to pin
`common/` to the **exact stock commit `1481f357a31c`** (build sets
`STOCK_COMMON_SHA` / `STOCK_BUILD_NUMBER`). Then the stock vendor `.ko`s load
unchanged. `safe` (config-only bbr/zstd) keeps CRCs identical → WiFi-safe;
**`aggressive` (ThinLTO) changes CRCs → will re-break WiFi, do not flash.**
Full analysis: `evidence/S688LN-2026-07-22/FINDINGS.md`.

## The plan (risk-ordered, one step at a time) — ⚠️ HISTORICAL / SUPERSEDED

> This ladder was followed to its end and **failed at flash time on every profile**
> (see the PARKED banner at the top). It is kept only as a record of what was tried.
> **Do not resume it.** The safe-profile gains (`bbr`, `zstd` zram, KFENCE off) now
> ship as the **S26U-KernelBoost** Magisk module on the stock kernel instead.

1. **`stock` build — do this first.** Zero changes. Proves the checkout → Kleaf
   build → `boot.img` pack chain works and gives you a boot image to **`fastboot
   boot`** (temporary, NOT flash). If the phone boots and Wi-Fi/display/modem all
   come up, the KMI is intact and prebuilt Unisoc vendor modules load against our
   kernel — the green light for tuning.
2. **`safe` build.** Adds only KMI-safe defaults: TCP **bbr**, zram **zstd**.
   No ABI/struct change, so vendor modules are unaffected. `fastboot boot`, verify.
3. **`aggressive` build.** Adds ThinLTO + strips the debug bloat the stock device
   shipped enabled (KASAN/KFENCE/lockup/sched_debug/ftrace/profiling). Bigger
   wins, but these *can* perturb the KMI — the build runs with
   `--kmi_symbol_list_strict_mode=false` and the **`fastboot boot` probe is
   mandatory** before you ever flash.

## How to run
Actions tab → **Build S26U GKI** → *Run workflow* → pick `profile` → Run.
Artifacts (`Image`, `boot.img`, `System.map`, `SHA256SUMS.txt`) attach to the run.

## Golden safety rules (from the owner)
- **Never flash blind.** Always `fastboot boot out/boot.img` first; if it hangs,
  reboot and you're back on stock — nothing was written.
- Only ever swap the **kernel** in boot.img. **Never** touch `init_boot`,
  `vendor_boot`, or thermal.
- Keep Magisk for root (don't rebuild root into the kernel). KernelSU upstream
  dropped built-in/GKI mode; susfs on 6.6 GKI is experimental.

*Source of truth for the whole S26U project lives in the private repo
`itel-s26-ultra-Dev`.*
