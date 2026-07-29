#!/usr/bin/env bash
# apply_tuning.sh <profile> <common_dir>
# Patches gki_defconfig for the S26U (T7300), KMI-consciously.
# profile: safe | aggressive | ksun
#
# ── Tier-A (KMI-safe, value-of-default changes only) ─────────────────────
# Bakes the S26U-KernelBoost runtime trio into the kernel as DEFAULTS:
#   1. CONFIG_DEFAULT_BBR=y              — default TCP congestion cubic -> bbr
#   2. CONFIG_ZRAM_DEF_COMP_ZSTD=y       — default zram compressor lzo-rle -> zstd
#   3. CONFIG_KFENCE_SAMPLE_INTERVAL 500 -> 0 — KFENCE stays compiled in (all
#      symbols/CRCs intact) but sampling is OFF from boot (Kconfig help text:
#      "Set this to 0 to disable KFENCE by default" — lib/Kconfig.kfence).
# No symbol is added/removed and no struct/ABI/LTO changes, so MODVERSIONS
# CRCs stay byte-identical to stock -> vendor WiFi/BT modules unaffected.
# The device has run all three via the KernelBoost/Flow module since
# 2026-07-22 (VERIFIED), so this changes WHEN defaults apply, not behavior.
#
# ── check_defconfig canonical-form rules (hard-won, do not violate) ──────
# Kleaf runs savedefconfig and byte-compares to gki_defconfig:
#   * Lines must sit at their savedefconfig CANONICAL menu position
#     (insert_before anchors below, VERIFIED against pinned tree 1481f357a31c
#     with real `make savedefconfig` in the dev sandbox).
#   * savedefconfig OMITS promptless derived strings: CONFIG_DEFAULT_TCP_CONG
#     and CONFIG_ZRAM_DEF_COMP are recomputed from the choice selectors and
#     MUST NOT be written to the file (an extra line = gate failure).
#   * savedefconfig OMITS options equal to their Kconfig default: never write
#     CONFIG_KSU=y (default y once its Kconfig is sourced).
#
# ── Why ksun does NOT write CONFIG_KSU=y ─────────────────────────────────
# KSU-Next's Kconfig is `config KSU ... default y`. Once its Kconfig is sourced
# (setup.sh) with deps satisfied, CONFIG_KSU resolves to y by DEFAULT, so an
# explicit line fails check_defconfig (-CONFIG_KSU=y). Enabling KSU (default y)
# forces its deps KPROBES/EXT4_FS explicit in canonical position (already
# present in stock; insert_before keeps them pinned). The "Verify KernelSU is
# compiled in" CI gate confirms CONFIG_KSU actually landed.
set -euo pipefail

PROFILE="${1:?profile required (safe|aggressive|ksun)}"
COMMON="${2:?path to ACK common/ required}"
DEFCONFIG="$COMMON/arch/arm64/configs/gki_defconfig"

[ -f "$DEFCONFIG" ] || { echo "gki_defconfig not found at $DEFCONFIG"; exit 1; }
cp "$DEFCONFIG" "$DEFCONFIG.orig"

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

# Change the VALUE of an existing config line in place (position is already
# canonical). Fails loudly if the expected stock line is missing.
set_value_in_place() {
  local key="$1" old="$2" new="$3"
  grep -qxF "${key}=${old}" "$DEFCONFIG" || {
    echo "::error::expected stock line '${key}=${old}' not found — tree drifted, refusing to guess."; exit 1; }
  sed -i "s/^${key}=${old}$/${key}=${new}/" "$DEFCONFIG"
}

# ---- Tier-A: the KernelBoost trio as kernel DEFAULTS (KMI-safe) ----
# Canonical positions VERIFIED 2026-07-29 against pinned tree 1481f357a31c
# with real savedefconfig: DEFAULT_BBR emits right after CONFIG_TCP_CONG_BBR=y
# (anchor CONFIG_IPV6_ROUTER_PREF=y); ZRAM_DEF_COMP_ZSTD emits right after
# CONFIG_ZRAM=m (anchor CONFIG_ZRAM_WRITEBACK=y); KFENCE_SAMPLE_INTERVAL is a
# value change on its existing line (500 -> 0).
apply_tier_a() {
  insert_before "CONFIG_DEFAULT_BBR=y"       "CONFIG_IPV6_ROUTER_PREF=y"
  insert_before "CONFIG_ZRAM_DEF_COMP_ZSTD=y" "CONFIG_ZRAM_WRITEBACK=y"
  set_value_in_place CONFIG_KFENCE_SAMPLE_INTERVAL 500 0
}

if [ "$PROFILE" = "ksun" ]; then
  # KSU (default y) deps explicit in canonical position (stock already has
  # both; insert_before keeps them pinned at the savedefconfig anchors).
  insert_before "CONFIG_KPROBES=y"  "CONFIG_JUMP_LABEL=y"
  insert_before "CONFIG_EXT4_FS=y"  "CONFIG_EXT4_FS_POSIX_ACL=y"
  # v0.8: bake the tier-A defaults into the ksun kernel. The runtime module
  # (S26U-Flow/S26U-KernelBoost) keeps writing the same values -> idempotent
  # confirmation, no module update needed.
  apply_tier_a
elif [ "$PROFILE" = "safe" ] || [ "$PROFILE" = "aggressive" ]; then
  apply_tier_a
fi

if [ "$PROFILE" = "aggressive" ]; then
  echo "" >> "$DEFCONFIG"
  echo "# ---- aggressive: ThinLTO + strip debug (KMI-perturbing, probe first) ----" >> "$DEFCONFIG"
  # WARNING (2026-07-29): these appended lines are NOT savedefconfig-canonical
  # and will FAIL check_defconfig as-is. aggressive is a parked experiment
  # (ThinLTO changes symbol CRCs -> re-breaks WiFi; do not flash). Fixing its
  # canonical placement is deferred until someone revives it deliberately.
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
