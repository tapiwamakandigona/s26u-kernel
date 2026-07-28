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
