#!/usr/bin/env bash
# Camp Kernel - Non-GKI 4.19 SuSFS Integration Script
# Place this file at: .github/susfs/apply-susfs.sh
#
# Usage (run from kernel root):
#   bash /path/to/.github/susfs/apply-susfs.sh
#   bash /path/to/.github/susfs/apply-susfs.sh --defconfig arch/arm64/configs/exynos850-a13nsxx_defconfig

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults (overridden by .github/susfs/susfs.conf if present)
SUSFS_REPO="JackA1ltman/NonGKI_Kernel_Build_2nd"
SUSFS_BRANCH="mainline"
SUSFS_PATCH_REL="Patches/Patch/susfs_patch_to_4.19.patch"
SUSFS_INLINE_SCRIPT_REL="Patches/susfs_inline_hook_patches.sh"

SUSFS_INLINE_HOOK="y"
SUSFS_SUS_PATH="y"
SUSFS_SUS_MOUNT="y"
SUSFS_SUS_KSTAT="y"
SUSFS_SPOOF_UNAME="y"
SUSFS_ENABLE_LOG="y"
SUSFS_HIDE_KSU_SUSFS_SYMBOLS="y"
SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG="y"
SUSFS_OPEN_REDIRECT="y"
SUSFS_SUS_MAP="y"
SUSFS_PRIORITY_UID_FILTER="auto"

if [ -f "${SCRIPT_DIR}/susfs.conf" ]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/susfs.conf"
fi

apply_defconfig() {
  local D="$1"
  local K="drivers/kernelsu/Kconfig"
  test -f "$D" || { echo "::error::Defconfig not found: $D"; exit 1; }
  test -f "$K" || { echo "::error::KernelSU Kconfig not found: $K"; exit 1; }

  has_opt() { grep -qE "^[[:space:]]*config[[:space:]]+$1([[:space:]]|$)" "$K"; }
  set_y()   { sed -i "/^CONFIG_$1=/d;/^# CONFIG_$1 is not set/d" "$D"; echo "CONFIG_$1=y" >> "$D"; }
  set_n()   { sed -i "/^CONFIG_$1=/d;/^# CONFIG_$1 is not set/d" "$D"; echo "# CONFIG_$1 is not set" >> "$D"; }
  set_opt() {
    local opt="$1" val="$2"
    has_opt "$opt" || return 0
    if [ "$val" = "y" ]; then set_y "$opt"; else set_n "$opt"; fi
  }

  # Mutually exclusive with SuSFS in SukiSU-Nova builtin-new
  set_n KSU_HACK_ARM64_BRANCH_LINK
  set_n KSU_TAMPER_SYSCALL_TABLE

  set_y KSU_SUSFS
  set_opt KSU_SUSFS_INLINE_HOOK "$SUSFS_INLINE_HOOK"
  set_opt KSU_SUSFS_SUS_PATH "$SUSFS_SUS_PATH"
  set_opt KSU_SUSFS_SUS_MOUNT "$SUSFS_SUS_MOUNT"
  set_opt KSU_SUSFS_SUS_KSTAT "$SUSFS_SUS_KSTAT"
  set_opt KSU_SUSFS_SPOOF_UNAME "$SUSFS_SPOOF_UNAME"
  set_opt KSU_SUSFS_ENABLE_LOG "$SUSFS_ENABLE_LOG"
  set_opt KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS "$SUSFS_HIDE_KSU_SUSFS_SYMBOLS"
  set_opt KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG "$SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG"
  set_opt KSU_SUSFS_OPEN_REDIRECT "$SUSFS_OPEN_REDIRECT"
  set_opt KSU_SUSFS_SUS_MAP "$SUSFS_SUS_MAP"

  if has_opt KSU_SUSFS_PRIORITY_UID_FILTER; then
    if [ "$SUSFS_PRIORITY_UID_FILTER" = "y" ]; then
      set_y KSU_SUSFS_PRIORITY_UID_FILTER
    elif [ "$SUSFS_PRIORITY_UID_FILTER" = "auto" ]; then
      if grep -q 'susfs_set_priority_uid_filter' include/linux/susfs.h 2>/dev/null; then
        set_y KSU_SUSFS_PRIORITY_UID_FILTER
      else
        set_n KSU_SUSFS_PRIORITY_UID_FILTER
      fi
    else
      set_n KSU_SUSFS_PRIORITY_UID_FILTER
    fi
  fi
}

apply_patches() {
  local SUSFS_SRC=""
  local PATCH_FILE=""
  local INLINE_SCRIPT=""

  # 1. Prefer local files placed directly in .github/susfs/
  if [ -f "${SCRIPT_DIR}/susfs_patch_to_4.19.patch" ]; then
    SUSFS_SRC="repo:.github/susfs"
    PATCH_FILE="${SCRIPT_DIR}/susfs_patch_to_4.19.patch"
    [ -f "${SCRIPT_DIR}/susfs_inline_hook_patches.sh" ] && INLINE_SCRIPT="${SCRIPT_DIR}/susfs_inline_hook_patches.sh"
    [ -f "${SCRIPT_DIR}/fs/susfs.c" ] && cp -v "${SCRIPT_DIR}/fs/susfs.c" fs/susfs.c
    if [ -d "${SCRIPT_DIR}/include/linux" ]; then
      cp -v "${SCRIPT_DIR}/include/linux/"* include/linux/
    fi
  else
    # 2. Clone configured Non-GKI SuSFS repo (default: JackA1ltman/NonGKI_Kernel_Build_2nd@mainline)
    rm -rf /tmp/nongki_susfs
    git clone --depth=1 --branch "${SUSFS_BRANCH}" "https://github.com/${SUSFS_REPO}.git" /tmp/nongki_susfs
    local SUSFS_SHA
    SUSFS_SHA="$(git -C /tmp/nongki_susfs rev-parse --short=12 HEAD)"
    SUSFS_SRC="${SUSFS_REPO}@${SUSFS_BRANCH} (${SUSFS_SHA})"
    PATCH_FILE="/tmp/nongki_susfs/${SUSFS_PATCH_REL}"
    [ -f "/tmp/nongki_susfs/${SUSFS_INLINE_SCRIPT_REL}" ] && INLINE_SCRIPT="/tmp/nongki_susfs/${SUSFS_INLINE_SCRIPT_REL}"
  fi

  test -f "$PATCH_FILE" || { echo "::error::Missing SuSFS patch file: $PATCH_FILE"; exit 1; }
  echo "Using SuSFS source: ${SUSFS_SRC}"

  local PATCH_RC=0
  patch -p1 -F3 --forward < "$PATCH_FILE" || PATCH_RC=$?
  if [ "$PATCH_RC" -ne 0 ]; then
    echo "::warning::$(basename "$PATCH_FILE") had rejects (exit $PATCH_RC); listing .rej files:"
    find . -name '*.rej' -print -exec head -n 40 {} \;
    exit "$PATCH_RC"
  fi

  if [ -n "$INLINE_SCRIPT" ]; then
    bash "$INLINE_SCRIPT"
  fi

  # Apply any device-specific fixup patches placed in .github/susfs/fixups/
  if [ -d "${SCRIPT_DIR}/fixups" ]; then
    for fix in "${SCRIPT_DIR}/fixups"/*.patch "${SCRIPT_DIR}/fixups"/*.diff; do
      [ -f "$fix" ] || continue
      echo "Applying SuSFS fixup: $(basename "$fix")"
      git apply -C1 --verbose "$fix" || patch -p1 -F3 --forward --no-backup-if-mismatch < "$fix"
    done
  fi

  test -f fs/susfs.c && test -f include/linux/susfs.h
  local SUSFS_VER
  SUSFS_VER="$(grep -E '^#define SUSFS_VERSION' include/linux/susfs.h | awk '{print $3}' | tr -d '"' || echo 'unknown')"
  echo "Detected SUSFS_VERSION: ${SUSFS_VER}"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "version=${SUSFS_VER}" >> "$GITHUB_OUTPUT"
    echo "source=${SUSFS_SRC}"  >> "$GITHUB_OUTPUT"
  fi
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "### SuSFS (Non-GKI 4.19)"
      echo "- source: \`${SUSFS_SRC}\` - \`SUSFS_VERSION=${SUSFS_VER}\`"
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

if [ "${1:-}" = "--defconfig" ]; then
  shift
  apply_defconfig "${1:?defconfig path required}"
else
  apply_patches
fi
