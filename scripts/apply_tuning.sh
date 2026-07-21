#!/usr/bin/env bash
# apply_tuning.sh <profile> <common_dir>
# Patches gki_defconfig with KMI-conscious tuning for the S26U (T7300).
# profile: safe | aggressive
set -euo pipefail

PROFILE="${1:?profile required (safe|aggressive)}"
COMMON="${2:?path to ACK common/ required}"
DEFCONFIG="$COMMON/arch/arm64/configs/gki_defconfig"

[ -f "$DEFCONFIG" ] || { echo "gki_defconfig not found at $DEFCONFIG"; exit 1; }
cp "$DEFCONFIG" "$DEFCONFIG.orig"

# Helper: force a config line, replacing any existing form.
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

echo "" >> "$DEFCONFIG"
echo "# ===== S26U tuning ($PROFILE) =====" >> "$DEFCONFIG"

# ---- KMI-SAFE tier (no ABI/struct impact): default congestion + zram comp ----
# Stock device runs DEFAULT_TCP_CONG=cubic with BBR compiled in -> flip default.
set_cfg CONFIG_DEFAULT_BBR y
set_cfg CONFIG_DEFAULT_TCP_CONG '"bbr"'
# Stock device runs zram default lzo-rle with zstd compiled in -> flip default.
set_cfg CONFIG_ZRAM_DEF_COMP_ZSTD y
set_cfg CONFIG_ZRAM_DEF_COMP '"zstd"'

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
