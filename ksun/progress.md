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

## Iteration 5 — 2026-07-29 ~21:30 UTC — v0.8: tier-A defaults baked into the kernel (Viktor)
- Owner directive: "do thorough research on how kernels are made n work, then make the kernel
  update, no errors, be autonomous." Read harness v3.0.1 (subagent-toolkit tag) — single agent, evidence-first.
- RESEARCH (all VERIFIED against primary sources, write-up: docs/how-gki-kernels-work.md):
  GKI/KMI/module-signing model (source.android.com), BBR-vs-cubic on lossy/satellite links
  (arXiv:2607.07133 Starlink study; WPI testbed), zstd-vs-lzo-rle zram (LWN 973757), KFENCE
  default-off semantics (lib/Kconfig.kfence help text at pinned SHA).
- PINNED-SOURCE FACTS (1481f357a31c, fetched from android.googlesource): stock gki_defconfig has
  TCP_CONG_BBR=y:163, CRYPTO_ZSTD=y:741, ZRAM=m:331, KFENCE_SAMPLE_INTERVAL=500:777; choice
  defaults are DEFAULT_CUBIC and ZRAM_DEF_COMP_LZORLE.
- LOCAL RIG (no CI guessing): downloaded the full pinned tree tarball, built flex/bison/m4 from
  source, replicated KSU setup.sh wiring (v3.3.0 clone). Pristine savedefconfig vs committed file
  = 8 toolchain-gated omissions (baseline D0; Kleaf's clang env has them all — CI-green v0.7.1
  proves it). ksun v0.7.1 replica: delta == D0 exactly, CONFIG_KSU=y.
- KEY DISCOVERY: savedefconfig OMITS promptless derived strings (DEFAULT_TCP_CONG,
  ZRAM_DEF_COMP) — the old set_cfg append-at-EOF pattern (safe profile) can NEVER pass
  check_defconfig; explains the historical safe-profile failures. v0.8 = canonical 3-line delta.
- VERIFIED: v0.8 apply_tuning.sh produces exactly +CONFIG_DEFAULT_BBR=y (after TCP_CONG_BBR),
  +CONFIG_ZRAM_DEF_COMP_ZSTD=y (after ZRAM=m), KFENCE_SAMPLE_INTERVAL 500->0; savedefconfig delta
  == D0 byte-for-byte; .config effective: bbr default, zstd zram default, kfence interval 0, KSU=y.
- build.yml: REL_VER/zip/kit -> v0.8; new ksun hard gate (5 values in built .config); STEP-2 hash
  verification moved to CI-time injection (__BOOT_SHA256__/__WIFIZIP_SHA256__ placeholders +
  gates) — kills the post-build hash-pin commit dance and any stale-hash kit.
- flash-kit/ksun labels -> v0.8 (bat CRLF preserved); READ-ME-FIRST rewritten; module.prop v0.8-ksun.
- Next: branch + PR (never push main), dispatch ksun CI on branch, monitor ~48min, record evidence.

## Iteration 6 — 2026-07-29 ~22:15 UTC — self-review catch: tuning gate was missing (Viktor)
- Run 30492435675 (commit 4952db2) went GREEN: check_defconfig passed with the 3-line delta,
  apply-step log shows the exact defconfig diff, hash injection executed, release
  v0.8-ksun-run30492435675 published with kit + wifi zip + SHA256SUMS.
- BUT post-CI step-list audit showed the promised "Verify v0.8 tier-A tuning landed" gate was
  NOT in the committed build.yml (lost between local drafting and commit). Evidence rule: claims
  need the gate to actually run. Added the step (5 exact-line greps on the built .config,
  hard-fails), YAML-validated, pushed as commit 2 on the PR branch; re-dispatching ksun CI.
- The superseded release will be deleted once the gated run is green, so only ONE v0.8 release
  exists (same-release pairing rule stays unambiguous for the owner).

## Iteration 7 — 2026-07-29 ~23:00 UTC — v0.8 CI green WITH the tuning gate (Viktor)
- Run 30495119422 (commit 7241875) completed SUCCESS (~47m). New gate step
  "Verify v0.8 tier-A tuning landed (ksun hard gate)" ran and logged PASS for all 5 lines:
  CONFIG_DEFAULT_BBR=y, CONFIG_DEFAULT_TCP_CONG="bbr", CONFIG_ZRAM_DEF_COMP_ZSTD=y,
  CONFIG_ZRAM_DEF_COMP="zstd", CONFIG_KFENCE_SAMPLE_INTERVAL=0 → "v0.8 tier-A tuning confirmed".
  KSU gate, release-string gate, signed-modules gate all PASS as before.
- Release v0.8-ksun-run30495119422 published: S688LN-kernel-v0.8-ksun.zip (23.1 MB) +
  s688ln-wifi-fix-v0.8-ksun.zip + SHA256SUMS.txt.
- Superseded pre-gate release v0.8-ksun-run30492435675 DELETED (tag cleaned up) so exactly one
  v0.8 release exists; same-release boot.img/wifi-zip pairing stays unambiguous.
- features.json: v08-ci-green -> passes:true with run/gate/release evidence.
- Remaining gates are OWNER-only: v08-on-device-verified (fastboot boot, KSU Working + WiFi + BT
  + ~248 modules; defaults show bbr/zstd/kfence=0 with no module writes). PR #2 merge = owner call.
