# ksun progress (append-only)

## 2026-07-28 — kickoff (Viktor)
- Owner said "yes start building" → build the `ksun` profile proposed in DM
  (KernelSU-Next integrated into the kernel source).
- Read v0.6 SOLVED state: build.yml, apply_tuning.sh, magisk-module (post-fs-data
  signed-rfkill loader), FINDINGS 2026-07-28. Fully oriented. VERIFIED via file reads.
- Researched KSU-Next from live source (VERIFIED, not memory):
  - setup.sh: clones repo into GKI_ROOT, symlinks common/drivers/kernelsu ->
    KernelSU-Next/kernel, adds `obj-$(CONFIG_KSU) += kernelsu/` to
    common/drivers/Makefile + sources drivers/kernelsu/Kconfig. Accepts a tag arg.
  - v3.3.0 Kconfig: `config KSU` depends on KPROBES && EXT4_FS. Kprobe hook mode.
  - Stock config (evidence 2026-07-22) has ALL deps =y: KPROBES, KRETPROBES,
    HAVE_SYSCALL_TRACEPOINTS, EXT4_FS, OVERLAY_FS, F2FS_FS. VERIFIED via zcat grep.
- Decision: pin v3.3.0, kprobe mode, no susfs this round (CRC risk). Documented in PROJECT.md.

## Plan for this iteration
1. Extend apply_tuning.sh with `ksun` profile (safe tier + CONFIG_KSU=y). 
2. build.yml: add `ksun` choice + KSU-Next setup step + relaxed release-prefix gate for ksun + CONFIG_KSU verification gate + v0.7 module/kit naming.
3. Add flash-kit/ksun/ (KSU-aware README + root-agnostic wifi-fix module.prop).
4. Commit, push, trigger ksun CI run, monitor, record evidence.

## 2026-07-28 22:28 — implemented + pushed + CI triggered (Viktor)
- VERIFIED (file reads / YAML parse / git):
  - apply_tuning.sh `ksun` branch: bash -n OK; sets CONFIG_KSU=y + KMI-safe tier.
  - build.yml: pyyaml parse OK, 17 steps in correct order (KSU setup before tuning;
    CONFIG_KSU gate after boot pack; release + rfkill gates relaxed to prefix for ksun).
  - flash-kit/ksun: root-agnostic module.prop (id kept = s688ln_wifi_fix) + loader scripts + README + bat steps.
  - Commit ac3d0c6 pushed to origin/main (964dd75..ac3d0c6). Remote left tokenless.
- CI: workflow_dispatch build.yml profile=ksun -> run 30404659854 IN PROGRESS
  (https://github.com/tapiwamakandigona/s26u-kernel/actions/runs/30404659854).
- Note/assumption to watch: Kleaf may regen defconfig from fragments and drop raw
  gki_defconfig edits, but KSU Kconfig is `default y` with deps satisfied, so
  CONFIG_KSU should still be =y even then. Possible check_defconfig friction if
  Kleaf flags KSU symbols absent from gki_defconfig — will read the log and iterate.
- Pending CI verdict: build-succeeds, release-prefix-gate, signed-rfkill-carried,
  ksu-config-on, wifi-fix-module-packaged. On-device gate remains with owner.

## 2026-07-28 22:32 — CI run 30404659854 FAILED at Kleaf config (iteration 1)
- VERIFIED from job log: steps 1-9 passed (KSU-Next v3.3.0 integrated:
  common/drivers/Makefile:203 obj-$(CONFIG_KSU)+=kernelsu/ ; symlink present).
- Step 10 Build GKI (Kleaf) failed in ~48s at //common:kernel_aarch64_config:
  "ERROR: savedefconfig does not match common/arch/arm64/configs/gki_defconfig".
  savedefconfig canonical form wanted: +CONFIG_KPROBES=y (before JUMP_LABEL),
  +CONFIG_EXT4_FS=y (before EXT4_FS_POSIX_ACL). It OMITTED CONFIG_KSU=y
  (default y), CONFIG_KRETPROBES=y, DEFAULT_TCP_CONG="bbr", ZRAM_DEF_COMP="zstd"
  (all equal to their defaults once the bools are set). My appended,
  out-of-order block tripped the order- and default-sensitive check.
- FIX (iteration 2): rewrote apply_tuning.sh ksun branch to emit a MINIMAL,
  CANONICAL delta: insert only KPROBES + EXT4_FS at their menu anchors; do NOT
  write CONFIG_KSU (relies on default y); drop bbr/zstd for ksun (already done
  at runtime by S26U-KernelBoost Magisk module). Non-ksun (safe/aggressive)
  keep bbr/zstd in the else branch, unchanged.
- VERIFIED locally against a reconstructed stock-context fixture: output places
  KPROBES before JUMP_LABEL, EXT4_FS before POSIX_ACL, no CONFIG_KSU line, no
  marker comment, no trailing blank, ends with newline. All 8 assertions ok.

## Iteration 3 — 2026-07-28 23:28 UTC — CI GREEN, v0.7-ksun SHIPPED
- Run 30405396108 (head 2714dfd): **success** in ~48 min. All 17 steps green, including both ksun hard gates.
- Evidence (job log):
  - KSU integration: `common/drivers/Makefile:203:obj-$(CONFIG_KSU) += kernelsu/` after setup.sh v3.3.0.
  - KSU gate: `PASS: .../out/android15-6.6/common/.config has CONFIG_KSU=y`.
  - Release gate: `PASS (ksun): release string starts with the stock source prefix (6.6.102-android15-8-g1481f357a31c).`
    Full string: `6.6.102-android15-8-g1481f357a31c-dirty-ab14794947-4k` — `-dirty` comes from the in-tree KSU
    symlink/Makefile edits (setup.sh); this is exactly why the ksun gates use prefix match. MODVERSIONS
    CRCs are what module loading checks, not the release suffix, and rfkill.ko is same-run built+signed.
  - Module gate: `rfkill.ko vermagic ...-dirty-ab14794947-4k` + `PASS (ksun): rfkill.ko vermagic starts with the stock source prefix.`
- Release published: `v0.7-ksun-run30405396108` with `S688LN-kernel-v0.7-ksun.zip` (23.1 MB, kit incl. boot.img),
  `s688ln-wifi-fix-v0.7-ksun.zip` (root-agnostic loader), `SHA256SUMS.txt`.
- features.json: all CI-verifiable features now `passes:true` with evidence. Remaining: `on-device-verified`
  (OWNER gate — fastboot boot only, never flash blind).
- Learning: iteration-1 `check_defconfig` failure taught: gki_defconfig deltas must be minimal (no default-y
  entries like CONFIG_KSU=y) and menu-ordered; `insert_before()` anchor approach in apply_tuning.sh is the pattern.

## Iteration 4 — 2026-07-29 ~06:00 UTC — v0.7.1: fix KSU "version 1 too low" + WiFi/BT diagnosis (Viktor)
- OWNER on-device report (booted v0.7-ksun via fastboot boot): (a) KSU-Next manager
  shows "current kernel su next version 1 is too low ... upgrade 33188"; (b) WiFi + BT dead.
- Logs attached (S688LN-check/logs zips, uname=...-dirty, timestamps 07/29 07:39 CAT => THIS ksun boot):
  - dmesg VERIFIED: `KernelSU: handle_setresuid from 0 to 1000/10077/...` => KSU root IS working on-device.
  - dmesg VERIFIED: `rfkill: exports protected symbol rfkill_alloc` then `cfg80211/sprdbt_tty: Unknown
    symbol rfkill_alloc (err -2)` => the v0.5 signing-trust wall. rfkill.ko rejected (EPERM /
    "Permission denied" in fix_module_log) => whole WiFi/BT chain fails.
- ROOT CAUSE 1 (version=1): KernelSU-Next/kernel/Kbuild derives KSU_VERSION from
  `git rev-list --count HEAD`; Kleaf's HERMETIC SANDBOX omits .git => in-build git fails =>
  Kbuild takes `KSU_VERSION_FALLBACK := 1`. v3.3.0 real count = 3214 => correct code 30000+3214 = 33214.
  Manager v3.3.0 APK is literally `KernelSU_Next_v3.3.0_33214-release.apk` (wants kernel >= 33188).
- FIX 1 (VERIFIED locally, sed simulated on real v3.3.0 Kbuild): in the ksun integration step, after
  setup.sh, compute count on the RUNNER (full clone) and sed the Kbuild fallbacks:
  KSU_VERSION_FALLBACK := 33214, KSU_VERSION_TAG_FALLBACK := v3.3.0. Hard gate: numeric + >= 33188 +
  patch-applied grep. Export KSU_CODE to GITHUB_ENV for release notes. YAML parses (17 steps).
- ROOT CAUSE 2 (WiFi/BT): NOT the version. Module signing key is PER-BUILD (no checked-in key => Kleaf
  auto-gens per run). The wifi-fix module that ran was signed by a DIFFERENT run's key than the booted
  v0.7-ksun kernel (almost certainly the stale v0.6 s688ln_wifi_fix still in /data/adb/modules) =>
  kernel refuses rfkill.ko's protected-symbol exports. FIX: use boot.img + wifi-fix zip FROM THE SAME
  RELEASE, remove the old module first. Release notes updated to state this loudly.
- Naming bumped to v0.7.1 (REL_VER + WIFIZIP + KIT) so the new release/keys are unambiguous vs v0.7.
- Next: commit, push, trigger ksun CI, monitor, record evidence; then owner: fastboot boot new boot.img +
  install matched v0.7.1 wifi-fix zip + v3.3.0 manager APK.
