#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo SNAPSERVER_HOST=homeassistant.local ./setup.sh
#   sudo SNAPSERVER_HOST=192.168.0.87 ./setup.sh
# Optional:
#   SNAPSERVER_PORT=1704 (default)
#   ALSA_CARD_INDEX=1 (default; set after install if needed)
#   ALSA_CARD_NAME=seeed2micvoicec (default; used for snapclient --device)

SNAPSERVER_HOST="${SNAPSERVER_HOST:-homeassistant.local}"
SNAPSERVER_PORT="${SNAPSERVER_PORT:-1704}"
ALSA_CARD_INDEX="${ALSA_CARD_INDEX:-1}"
ALSA_CARD_NAME="${ALSA_CARD_NAME:-seeed2micvoicec}"

CFG="/boot/firmware/config.txt"
CMD="/boot/firmware/cmdline.txt"
[[ -f "$CFG" ]] || CFG="/boot/config.txt"
[[ -f "$CMD" ]] || CMD="/boot/cmdline.txt"

apt-get update -y
apt-get install -y git dkms i2c-tools alsa-utils snapclient

# Ensure I2C devices exist (/dev/i2c-1) across reboots
cat >/etc/modules-load.d/i2c.conf <<'EOF'
i2c-dev
i2c-bcm2835
EOF

# Boot config: disable onboard audio + enable I2C + load the Seeed overlay
cp -a "$CFG" "$CFG.bak"
grep -q "seeed-voicecard block" "$CFG" || cat >>"$CFG" <<'EOF'

# --- seeed-voicecard block ---
dtparam=audio=off
dtparam=i2c_arm=on
dtoverlay=seeed-2mic-voicecard
# --- end seeed-voicecard block ---
EOF

# Remove legacy bcm2835 audio cmdline flags that can interfere with routing/selection
if [[ -f "$CMD" ]]; then
  cp -a "$CMD" "$CMD.bak"
  sed -i \
    -e 's/\s*snd_bcm2835\.enable_headphones=[^ ]*//g' \
    -e 's/\s*snd_bcm2835\.enable_hdmi=[^ ]*//g' \
    -e 's/  */ /g; s/^ *//; s/ *$//' \
    "$CMD"
fi

# Install HinTak seeed-voicecard (better compatibility on newer kernels)
WORK="/opt/seeed-voicecard"
[[ -d "$WORK/.git" ]] || git clone https://github.com/HinTak/seeed-voicecard "$WORK"
git -C "$WORK" fetch --all --prune
for b in "v$(uname -r | cut -d. -f1-2)" master; do
  git -C "$WORK" checkout -f "$b" 2>/dev/null && break
done
git -C "$WORK" pull --ff-only || true
(cd "$WORK" && ./install.sh)

# Make the HAT the default ALSA device (sysdefault -> HAT)
cat >/etc/asound.conf <<EOF
defaults.pcm.card ${ALSA_CARD_INDEX}
defaults.ctl.card ${ALSA_CARD_INDEX}
EOF

# Snapclient: explicitly target the working ALSA device; do NOT force sampleformat
cat >/etc/default/snapclient <<EOF
SNAPCLIENT_OPTS="--host ${SNAPSERVER_HOST} --port ${SNAPSERVER_PORT} --player alsa --device plughw:CARD=${ALSA_CARD_NAME},DEV=0"
EOF

systemctl enable --now snapclient

echo "OK. Reboot next: sudo reboot"
echo "After reboot, verify:"
echo "  cat /proc/asound/cards"
echo "  aplay -l"
echo "  speaker-test -D plughw:CARD=${ALSA_CARD_NAME},DEV=0 -r 48000 -c 2"
echo "  systemctl status snapclient --no-pager"
