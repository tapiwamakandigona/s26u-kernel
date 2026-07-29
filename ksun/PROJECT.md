# ksun subproject — KernelSU-Next integrated into the S688LN GKI kernel

## Goal
Add a **`ksun` CI build profile** to `s26u-kernel` that builds the exact-stamp
S688LN GKI kernel **with KernelSU-Next compiled into the source** (kprobe hook
mode, no core-source patches), producing a `fastboot boot`-testable artifact.
Root lives *inside our Image* — nothing new is written to `init_boot`.

This is **additive / A-B**: the working v0.6 Magisk kernel is untouched. `ksun`
is a new option you `fastboot boot` to evaluate; you decide whether to keep it.

## Why this is on the table
We build the kernel ourselves → we own the source + signing key. That's the
ideal case for kernel-integrated root. KSU-Next kprobe mode is *additive*: it
adds a driver + kprobe hooks, does not modify existing exported-symbol
signatures, so it should be CRC-neutral vs the vendor modules (the constraint
that bans the `aggressive`/ThinLTO profile).

## Key decisions (2026-07-28)
- **Pin KSU-Next `v3.3.0`** (latest stable tag). Deps: `CONFIG_KPROBES` +
  `CONFIG_EXT4_FS` — both already `=y` in stock. Kprobe hook mode → no patches
  to `common/` core source (fs/exec.c etc.), lowest CRC risk.
- Prereqs VERIFIED present in stock config: KPROBES, KRETPROBES,
  HAVE_SYSCALL_TRACEPOINTS, EXT4_FS, OVERLAY_FS, F2FS_FS.
- **susfs is NOT in this iteration.** susfs patches `common/` core (fs/) and can
  shift struct layouts → CRC risk + dirties tree more. Ship KSU-Next first,
  verify WiFi/BT survive, then evaluate susfs as a separate profile.
- **Release-string gate relaxed for ksun only**: KSU integration edits
  `common/drivers/{Makefile,Kconfig}` (+ symlink) → tree is no longer
  byte-identical to stock, so uname may gain a suffix. Gate = *prefix* match on
  `6.6.102-android15-8-g1481f357a31c` (correct source + KMI + stamp present) and
  echo the full string. The v0.6 exact-match gate stays for stock/safe.
- **KMI strict mode left at default (ON) for ksun** — this is the real in-CI CRC
  gate. If KSU trips it on a benign new symbol we add `--kmi_symbol_list_strict_mode=false`
  in a follow-up (one change/iteration).
- **Signed-rfkill mechanism reused unchanged.** The ksun kernel is still
  self-built → still rejects Google-signed `rfkill.ko` (protected exports). Same
  same-run signed `gki/*.ko` + post-fs-data loader. The WiFi-fix module is
  root-agnostic (runs under Magisk OR KernelSU), so it's a drop-in.

## Definition of done
See features.json. Ultimate on-device gate stays with the owner: `fastboot boot`
(fastbootd) → root works (KSU manager) + WiFi + BT + 248 modules. Never flash blind.

## v0.8 — tier-A config defaults baked in (2026-07-29)
The KernelBoost runtime trio becomes kernel factory defaults (ksun profile):
`CONFIG_DEFAULT_BBR=y` (TCP cubic→bbr), `CONFIG_ZRAM_DEF_COMP_ZSTD=y`
(lzo-rle→zstd), `CONFIG_KFENCE_SAMPLE_INTERVAL=500→0` (KFENCE off from boot,
code stays built-in). Value-of-default changes only → MODVERSIONS CRCs
byte-identical to stock → vendor WiFi/BT unaffected (KMI strict mode stays ON
as the in-CI CRC gate). Device has run these values via the module since
2026-07-22 (VERIFIED), so on-device behavior is unchanged — defaults just
apply from boot. Research base + plain-English explainer:
`docs/how-gki-kernels-work.md`.

Hard-won config-gate rules (VERIFIED locally against pinned tree 1481f357a31c
with real `make savedefconfig`, before push):
- `check_defconfig` byte-compares the file to savedefconfig's canonical form.
- savedefconfig OMITS promptless derived strings → never write
  `CONFIG_DEFAULT_TCP_CONG` / `CONFIG_ZRAM_DEF_COMP` (extra line = gate fail).
- Canonical positions: `DEFAULT_BBR` after `CONFIG_TCP_CONG_BBR=y`;
  `ZRAM_DEF_COMP_ZSTD` after `CONFIG_ZRAM=m`; KFENCE interval = in-place
  value change. The old `set_cfg` append-at-EOF pattern can never pass.
- New CI hard gate: built `.config` must contain all five effective values.
