#!/usr/bin/env bash
set -euo pipefail

# ReSpeaker 2-Mic HAT v1 (WM8960) on Debian 13 (trixie) + rpt kernel 6.12.x
# REQUIRED: use dtoverlay=respeaker-2mic-v1_0 from Seeed seeed-linux-dtoverlays.
# DO NOT use: seeed-2mic-voicecard, googlevoicehat-soundcard, snd_rpi_googlevoicehat_soundcard.

log() { echo -e "\n==> $*\n"; }
die() { echo -e "\nERROR: $*\n" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"

CFG="/boot/firmware/config.txt"
OVERLAYS_DIR="/boot/firmware/overlays"

[[ -f "$CFG" ]] || die "Missing $CFG (expected Debian/RPi firmware layout)."

REPO_URL="https://github.com/Seeed-Studio/seeed-linux-dtoverlays.git"
WORKDIR="/opt/seeed-linux-dtoverlays"
DTBO_REL="overlays/rpi/respeaker-2mic-v1_0-overlay.dtbo"
DTBO_DST="${OVERLAYS_DIR}/respeaker-2mic-v1_0.dtbo"
OVERLAY_LINE="dtoverlay=respeaker-2mic-v1_0"

log "Installing build deps..."
apt-get update -y
apt-get install -y git make device-tree-compiler

log "Backing up $CFG ..."
cp -a "$CFG" "${CFG}.bak.$(date +%Y%m%d%H%M%S)"

log "Removing known-incompatible overlays from $CFG (if present)..."
# These are known to break on kernel 6.12.x for this HAT in our testing.
sed -i \
  -e '/^\s*dtoverlay=seeed-2mic-voicecard\s*$/d' \
  -e '/^\s*dtoverlay=googlevoicehat-soundcard\s*$/d' \
  -e '/^\s*dtoverlay=snd_rpi_googlevoicehat_soundcard\s*$/d' \
  -e '/^\s*dtoverlay=googlevoicehat\s*$/d' \
  -e '/^\s*dtoverlay=googlevoicehat\-soundcard\s*$/d' \
  "$CFG"

log "Ensuring I2S enabled (dtparam=i2s=on)..."
if grep -q '^\s*dtparam=i2s=' "$CFG"; then
  sed -i 's/^\s*dtparam=i2s=.*/dtparam=i2s=on/' "$CFG"
else
  echo 'dtparam=i2s=on' >> "$CFG"
fi

log "Ensuring onboard audio disabled (dtparam=audio=off) to prevent HDMI/default hijacking..."
# Remove all dtparam=audio=... lines and add one dtparam=audio=off at the end.
sed -i '/^\s*dtparam=audio=/d' "$CFG"
echo 'dtparam=audio=off' >> "$CFG"

log "Cloning/building Seeed overlay dtbo..."
rm -rf "$WORKDIR"
git clone "$REPO_URL" "$WORKDIR"
cd "$WORKDIR"

# Build only the dtbo we need.
make "$DTBO_REL"

log "Installing overlay to $DTBO_DST ..."
install -d "$OVERLAYS_DIR"
install -m 0644 "$DTBO_REL" "$DTBO_DST"

log "Enabling overlay line in $CFG ..."
# Ensure only one instance exists
sed -i "/^\s*dtoverlay=respeaker-2mic-v1_0\s*$/d" "$CFG"
echo "$OVERLAY_LINE" >> "$CFG"

log "Done. Current relevant config lines:"
grep -nE '^(dtparam=i2s|dtparam=audio|dtoverlay=)' "$CFG" || true

cat <<'EOF'

NEXT STEP (required):
  sudo reboot

After reboot, verify:
  aplay -l
  cat /proc/asound/cards
  sudo dmesg -T | egrep -i 'wm8960|mclk|asoc|i2s|respeaker|seeed' | tail -n 120
  speaker-test -D plughw:CARD=seeed2micvoicec,DEV=0 -c 2 -r 48000

If you see "No MCLK configured", the wrong overlay is still being used somewhere.
EOF
