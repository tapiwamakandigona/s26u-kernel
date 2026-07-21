# S26U GKI kernel CI

Free-runner CI that builds a custom **GKI kernel** for the **itel S26 Ultra**
(S688LN · Unisoc T7300 · ums9360 · Android 15). Actions is billing-blocked on the
private dev repo, so the build lives here on a public repo where GitHub runners are
free (same pattern as the PodEQ mirror).

Device stock kernel (VERIFIED from recon): `6.6.102-android15-8` GKI, built with
clang 18 / kleaf, `LTO_NONE`, MODVERSIONS + ABI symbol list (`abi_symbollist.raw`),
default TCP `cubic`, zram `lzo-rle`.

## The plan (risk-ordered, one step at a time)

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
