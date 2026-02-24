#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n==> $*\n"; }

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

BOOT_CFG=""
if [[ -f /boot/firmware/config.txt ]]; then
  BOOT_CFG="/boot/firmware/config.txt"
elif [[ -f /boot/config.txt ]]; then
  BOOT_CFG="/boot/config.txt"
else
  echo "Could not find /boot/firmware/config.txt or /boot/config.txt"
  exit 1
fi

log "Using boot config: $BOOT_CFG"

backup="$BOOT_CFG.bak.$(date +%Y%m%d%H%M%S)"
cp -a "$BOOT_CFG" "$backup"
log "Backup created: $backup"

# Helpers: idempotent config edits
ensure_line() {
  local line="$1"
  grep -qF "$line" "$BOOT_CFG" || echo "$line" >> "$BOOT_CFG"
}

comment_out_matching() {
  local pattern="$1"
  # comment out lines that match pattern and aren't already commented
  sed -i -E "s/^([^#].*${pattern}.*)/# \1/g" "$BOOT_CFG"
}

uncomment_matching() {
  local pattern="$1"
  sed -i -E "s/^#\s*(.*${pattern}.*)/\1/g" "$BOOT_CFG"
}

# 1) Avoid legacy audio conflicts (snd_bcm2835) when using I2S HATs
# Keep ONE authoritative setting: audio=off
comment_out_matching "dtparam=audio="
ensure_line "dtparam=audio=off"

# 2) Ensure I2S is enabled
comment_out_matching "dtparam=i2s="
ensure_line "dtparam=i2s=on"

# 3) Switch overlays:
# The seeed overlay on 6.12 is commonly failing with WM8960 "No MCLK configured" -> hw_params -22.
# Use googlevoicehat-soundcard overlay for kernel/device-tree compatibility.
comment_out_matching "dtoverlay=seeed-2mic-voicecard"
comment_out_matching "dtoverlay=i2s-mmap"
# (i2s-mmap is not required for snapclient playback; it can complicate things on newer kernels.)
comment_out_matching "dtoverlay=googlevoicehat-soundcard"
ensure_line "dtoverlay=googlevoicehat-soundcard"

log "Boot config updated (overlay + i2s + audio)."

log "Installing ALSA utils for verification..."
apt-get update -y
apt-get install -y alsa-utils

log "Attempting to detect WM8960/voice HAT card name (pre-reboot may be stale)..."
aplay -l || true

# We'll write /etc/asound.conf after reboot ideally, but we can still make it robust:
# Choose first playback card containing 'wm8960' or 'voice' or 'seeed' or 'google'
CARD_ID="$(aplay -l 2>/dev/null | awk -F'[: ]+' '
  /^card [0-9]+:/ {
    card=$2; name=$4;
    if (tolower($0) ~ /(wm8960|voice|seeed|google)/) { print card; exit }
  }')"

if [[ -z "${CARD_ID:-}" ]]; then
  # Fallback: card 0 is typically the HAT if HDMI/analog is disabled, but not guaranteed pre-reboot.
  CARD_ID="0"
fi

log "Writing /etc/asound.conf default card -> $CARD_ID"
cat >/etc/asound.conf <<EOF
defaults.pcm.card $CARD_ID
defaults.ctl.card $CARD_ID
EOF

log "DONE. You MUST reboot for dtoverlay changes to take effect:"
echo "  sudo reboot"
echo
echo "After reboot, verify audio works:"
echo "  aplay -l"
echo "  speaker-test -D default -c 2 -r 48000"
