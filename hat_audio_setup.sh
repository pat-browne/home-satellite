#!/usr/bin/env bash
set -euo pipefail

# ReSpeaker 2-Mic HAT v1 (WM8960) setup for Debian 13 (trixie) + rpt kernel 6.12.x
# Key requirement: use Seeed's seeed-linux-dtoverlays overlay:
#   dtoverlay=respeaker-2mic-v1_0
#
# This avoids "wm8960: No MCLK configured" and ASoC hw_params errors on 6.12.x.

CFG="/boot/firmware/config.txt"
OVERLAYS_DIR="/boot/firmware/overlays"
REPO_DIR="$HOME/seeed-linux-dtoverlays"
DTBO_SRC="overlays/rpi/respeaker-2mic-v1_0-overlay.dtbo"
DTBO_DST="${OVERLAYS_DIR}/respeaker-2mic-v1_0.dtbo"
OVERLAY_LINE="dtoverlay=respeaker-2mic-v1_0"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
[[ -f "$CFG" ]] || die "Missing $CFG (expected Debian/RPi firmware layout)"

echo "[1/6] Installing build deps..."
apt-get update -y
apt-get install -y git make device-tree-compiler

echo "[2/6] Cleaning conflicting overlays in $CFG..."
# Remove known-incompatible overlays for this kernel line
sed -i \
  -e '/^\s*dtoverlay=seeed-2mic-voicecard\s*$/d' \
  -e '/^\s*dtoverlay=googlevoicehat-soundcard\s*$/d' \
  -e '/^\s*dtoverlay=snd_rpi_googlevoicehat_soundcard\s*$/d' \
  -e '/^\s*dtoverlay=googlevoicehat\s*$/d' \
  "$CFG"

echo "[3/6] Ensuring I2S enabled and onboard audio disabled..."
# Ensure dtparam=i2s=on (add if missing)
if grep -q '^\s*dtparam=i2s=' "$CFG"; then
  sed -i 's/^\s*dtparam=i2s=.*/dtparam=i2s=on/' "$CFG"
else
  echo 'dtparam=i2s=on' >> "$CFG"
fi

# Ensure dtparam=audio=off (avoid bcm2835 audio fighting for defaults)
# Remove duplicates first, then add a single line.
sed -i '/^\s*dtparam=audio=/d' "$CFG"
echo 'dtparam=audio=off' >> "$CFG"

echo "[4/6] Building Seeed overlay dtbo..."
rm -rf "$REPO_DIR"
git clone https://github.com/Seeed-Studio/seeed-linux-dtoverlays.git "$REPO_DIR"
cd "$REPO_DIR"
make "$DTBO_SRC"

echo "[5/6] Installing overlay dtbo to $DTBO_DST..."
install -d "$OVERLAYS_DIR"
install -m 0644 "$DTBO_SRC" "$DTBO_DST"

echo "[6/6] Enabling overlay line in $CFG..."
# Remove any stale instances and add once
sed -i "/^\s*dtoverlay=respeaker-2mic-v1_0\s*$/d" "$CFG"
echo "$OVERLAY_LINE" >> "$CFG"

echo
echo "HAT configured for kernel 6.12.x compatibility:"
echo "  - Overlay installed: $DTBO_DST"
echo "  - Enabled in config : $OVERLAY_LINE"
echo "  - I2S              : dtparam=i2s=on"
echo "  - Onboard audio    : dtparam=audio=off"
echo
echo "NEXT:"
echo "  sudo reboot"
echo
echo "After reboot, verify:"
echo "  aplay -l"
echo "  sudo dmesg -T | egrep -i 'wm8960|mclk|asoc|i2s|respeaker|seeed' | tail -n 80"
echo "  speaker-test -c 2 -r 48000"
