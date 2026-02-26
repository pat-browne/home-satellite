#!/usr/bin/env bash
set -euo pipefail

# Uninstall / revert HAT overlay + audio/I2S boot config changes.
# Targets Debian 13 (trixie) + Raspberry Pi boot firmware layout (/boot/firmware/config.txt).

BOOTCFG="/boot/firmware/config.txt"
OVERLAY_DIR="/boot/firmware/overlays"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/var/backups/home-satellite-uninstall-${STAMP}"

log() { echo "==> $*"; }
run() { log "$*"; "$@"; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run as root (use sudo)." >&2
    exit 1
  fi
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    run mkdir -p "$BACKUP_DIR"
    run cp -a "$f" "$BACKUP_DIR/"
    log "Backed up $f -> $BACKUP_DIR/$(basename "$f")"
  fi
}

# Remove *any* occurrences of exact config lines (ignores commented lines)
remove_cfg_line_exact() {
  local file="$1"
  local line="$2"
  [[ -f "$file" ]] || return 0
  # delete lines that match exactly (allow leading/trailing whitespace)
  run sed -i -E "\|^[[:space:]]*${line//\//\\/}[[:space:]]*$|d" "$file"
}

ensure_cfg_line() {
  local file="$1"
  local line="$2"
  [[ -f "$file" ]] || return 0
  if ! grep -qE "^[[:space:]]*${line//\//\\/}[[:space:]]*$" "$file"; then
    echo "$line" | run tee -a "$file" >/dev/null
  fi
}

main() {
  require_root

  log "Starting HAT uninstall / revert..."
  if [[ ! -f "$BOOTCFG" ]]; then
    echo "ERROR: $BOOTCFG not found. Are you on Raspberry Pi firmware layout?" >&2
    exit 1
  fi

  backup_file "$BOOTCFG"

  # Remove overlays we *know* cause problems / confusion for your fleet
  # (kitchen-satellite had these; office-satellite should not keep them either).
  log "Removing known-problem overlays from $BOOTCFG (if present)..."
  remove_cfg_line_exact "$BOOTCFG" "dtoverlay=seeed-2mic-voicecard"
  remove_cfg_line_exact "$BOOTCFG" "dtoverlay=googlevoicehat-soundcard"
  remove_cfg_line_exact "$BOOTCFG" "dtoverlay=googlevoicechat-soundcard"
  remove_cfg_line_exact "$BOOTCFG" "dtoverlay=i2s-mmap"

  # Remove the preferred kernel-compatible overlay as well (so reinstall is clean)
  remove_cfg_line_exact "$BOOTCFG" "dtoverlay=respeaker-2mic-v1_0"

  # Remove explicit I2S toggles (we'll let reinstall set them deterministically)
  remove_cfg_line_exact "$BOOTCFG" "dtparam=i2s=on"
  remove_cfg_line_exact "$BOOTCFG" "dtparam=i2s=off"

  # Remove explicit audio toggles; then set a clean baseline (audio=on).
  remove_cfg_line_exact "$BOOTCFG" "dtparam=audio=off"
  remove_cfg_line_exact "$BOOTCFG" "dtparam=audio=on"

  # Baseline: enable onboard audio so system has a sane default after uninstall.
  # (Your reinstall scripts will flip this back off and pin to the HAT.)
  ensure_cfg_line "$BOOTCFG" "dtparam=audio=on"

  # Optional: remove a copied dtbo for respeaker overlay if you had placed it there.
  # This is safe even if it doesn't exist.
  if [[ -d "$OVERLAY_DIR" ]]; then
    if [[ -f "$OVERLAY_DIR/respeaker-2mic-v1_0.dtbo" ]]; then
      backup_file "$OVERLAY_DIR/respeaker-2mic-v1_0.dtbo"
      run rm -f "$OVERLAY_DIR/respeaker-2mic-v1_0.dtbo"
      log "Removed $OVERLAY_DIR/respeaker-2mic-v1_0.dtbo"
    fi
  fi

  log "HAT uninstall complete."
  log "IMPORTANT: Reboot required to fully unload audio graph changes."
  log "Run: sudo reboot"
}

main "$@"
