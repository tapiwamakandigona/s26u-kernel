#!/usr/bin/env bash
# apply_tuning.sh <profile> <common_dir>
# Patches gki_defconfig for the S26U (T7300), KMI-consciously.
# profile: safe | aggressive | ksun
#
#   safe/aggressive = in-kernel network/zram tuning (BBR default + zstd zram).
#
#   ksun = KernelSU-Next compiled in via kprobe hooks. The KSU *source* wiring
#          (drivers/ symlink + Kconfig/Makefile) is done by the workflow's
#          KSU-Next setup.sh step, BEFORE this runs. This step only makes the
#          two KSU *dependencies* explicit in the defconfig.
#
# ── Why ksun does NOT tune BBR/zstd here ──────────────────────────────────
# BBR + zstd are already applied on-device at runtime by the S26U-KernelBoost
# Magisk module, so baking them into this kernel is redundant. Keeping the
# defconfig delta minimal also keeps Kleaf's check_defconfig happy.
#
# ── Why ksun does NOT write CONFIG_KSU=y ──────────────────────────────────
# KSU-Next's Kconfig is `config KSU ... default y`. Once its Kconfig is sourced
# (setup.sh) with deps satisfied, CONFIG_KSU resolves to y by DEFAULT. Kleaf
# runs `savedefconfig`, which OMITS any option equal to its Kconfig default, so
# an explicit `CONFIG_KSU=y` line makes check_defconfig fail with
#   "savedefconfig does not match gki_defconfig"  (-CONFIG_KSU=y).
# Enabling KSU (default y) DOES, however, force its dependencies KPROBES and
# EXT4_FS to become explicit in the minimized defconfig — and savedefconfig
# emits them in canonical menu position, so we must insert them there (not
# append them), or the check fails on ordering. The "Verify KernelSU is
# compiled in" CI gate confirms CONFIG_KSU actually landed.
set -euo pipefail

PROFILE="${1:?profile required (safe|aggressive|ksun)}"
COMMON="${2:?path to ACK common/ required}"
DEFCONFIG="$COMMON/arch/arm64/configs/gki_defconfig"

[ -f "$DEFCONFIG" ] || { echo "gki_defconfig not found at $DEFCONFIG"; exit 1; }
cp "$DEFCONFIG" "$DEFCONFIG.orig"

# Force a config line, replacing any existing form (appends — for tuning only).
set_cfg() {
  local key="$1" val="$2"
  sed -i "/^${key}=/d;/^# ${key} is not set/d" "$DEFCONFIG"
  echo "${key}=${val}" >> "$DEFCONFIG"
}
unset_cfg() {
  local key="$1"
  sed -i "/^${key}=/d;/^# ${key} is not set/d" "$DEFCONFIG"
  echo "# ${key} is not set" >> "$DEFCONFIG"
}
# Place a config line in CANONICAL position: remove any existing occurrence,
# then insert it immediately before a stable anchor line. Required for options
# that Kleaf's savedefconfig emits at a specific menu position (check_defconfig
# is order-sensitive). Fails loudly if the anchor is missing (pinned tree, so
# the anchor is stable; a miss means the tree drifted and must be re-checked).
insert_before() {
  local line="$1" anchor="$2"
  local key="${line%%=*}"          # e.g. CONFIG_KPROBES
  grep -qxF "$anchor" "$DEFCONFIG" || {
    echo "::error::anchor '$anchor' not found in gki_defconfig — tree drifted, refusing to guess."; exit 1; }
  # Drop every prior form of this key (any value, or "is not set").
  sed -i "/^${key}=/d;/^# ${key} is not set/d" "$DEFCONFIG"
  # Insert before the FIRST occurrence of the anchor.
  awk -v line="$line" -v anchor="$anchor" '
    $0==anchor && !done {print line; done=1}
    {print}
  ' "$DEFCONFIG" > "$DEFCONFIG.tmp" && mv "$DEFCONFIG.tmp" "$DEFCONFIG"
}

echo "" >> "$DEFCONFIG"
echo "# ===== S26U tuning ($PROFILE) =====" >> "$DEFCONFIG"

if [ "$PROFILE" = "ksun" ]; then
  # Remove the marker comment we just appended — ksun keeps the defconfig
  # canonical (savedefconfig strips comments/blank tails anyway, and a trailing
  # marker with nothing after it would itself cause a check_defconfig mismatch).
  sed -i '/^# ===== S26U tuning (ksun) =====$/d' "$DEFCONFIG"
  sed -i '${/^$/d}' "$DEFCONFIG"
  # KSU (default y) forces these two deps to be explicit, in canonical position.
  insert_before "CONFIG_KPROBES=y"  "CONFIG_JUMP_LABEL=y"
  insert_before "CONFIG_EXT4_FS=y"  "CONFIG_EXT4_FS_POSIX_ACL=y"
else
  # ---- KMI-SAFE tier (no ABI/struct impact): default cong + zram comp ----
  # Stock runs DEFAULT_TCP_CONG=cubic with BBR compiled in -> flip default.
  set_cfg CONFIG_DEFAULT_BBR y
  set_cfg CONFIG_DEFAULT_TCP_CONG '"bbr"'
  # Stock runs zram default lzo-rle with zstd compiled in -> flip default.
  set_cfg CONFIG_ZRAM_DEF_COMP_ZSTD y
  set_cfg CONFIG_ZRAM_DEF_COMP '"zstd"'
fi

if [ "$PROFILE" = "aggressive" ]; then
  echo "# ---- aggressive: ThinLTO + strip debug (KMI-perturbing, probe first) ----" >> "$DEFCONFIG"
  # ThinLTO (stock device shipped LTO_NONE=y).
  unset_cfg CONFIG_LTO_NONE
  set_cfg CONFIG_LTO_CLANG_THIN y
  # Strip debug/instrumentation bloat that the stock device left =y.
  unset_cfg CONFIG_KASAN
  unset_cfg CONFIG_KASAN_HW_TAGS
  unset_cfg CONFIG_KASAN_VMALLOC
  unset_cfg CONFIG_KFENCE
  unset_cfg CONFIG_LOCKUP_DETECTOR
  unset_cfg CONFIG_SOFTLOCKUP_DETECTOR
  unset_cfg CONFIG_HARDLOCKUP_DETECTOR
  unset_cfg CONFIG_SCHED_DEBUG
  unset_cfg CONFIG_FTRACE
  unset_cfg CONFIG_FUNCTION_TRACER
  unset_cfg CONFIG_FTRACE_SYSCALLS
  unset_cfg CONFIG_PROFILING
fi

echo "Applied '$PROFILE' tuning. Diff vs stock gki_defconfig:"
diff "$DEFCONFIG.orig" "$DEFCONFIG" || true
