#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo SNAPSERVER_HOST=homeassistant.local ./setup.sh
#   sudo SNAPSERVER_HOST=192.168.0.87 ./setup.sh
# Optional:
#   SNAPSERVER_PORT=1704 (default)

SNAPSERVER_HOST="${SNAPSERVER_HOST:-homeassistant.local}"
SNAPSERVER_PORT="${SNAPSERVER_PORT:-1704}"

CFG="/boot/firmware/config.txt"
CMD="/boot/firmware/cmdline.txt"
[[ -f "$CFG" ]] || CFG="/boot/config.txt"
[[ -f "$CMD" ]] || CMD="/boot/cmdline.txt"

apt-get update -y
apt-get install -y git dkms i2c-tools alsa-utils snapclient

# Ensure I2C devices exist across reboots
cat >/etc/modules-load.d/i2c.conf <<'EOF'
i2c-dev
i2c-bcm2835
EOF

# Boot config: disable onboard audio + enable I2C + load overlay
cp -a "$CFG" "$CFG.bak"
grep -q "seeed-voicecard block" "$CFG" || cat >>"$CFG" <<'EOF'

# --- seeed-voicecard block ---
dtparam=audio=off
dtparam=i2c_arm=on
dtoverlay=seeed-2mic-voicecard
# --- end seeed-voicecard block ---
EOF

# Remove legacy bcm2835 audio cmdline flags (can interfere with routing)
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

# Try to make the card visible without reboot (best-effort)
modprobe i2c-dev 2>/dev/null || true
modprobe i2c-bcm2835 2>/dev/null || true

# Auto-detect ALSA card index + name (prefer seeed/voicecard/wm8960)
detect_card() {
  local line
  line="$(aplay -l 2>/dev/null | grep -E '^card [0-9]+:' | grep -Ei 'seeed|voicecard|wm8960' | head -n1 || true)"
  if [[ -z "$line" ]]; then
    # fallback: any non-HDMI card
    line="$(aplay -l 2>/dev/null | grep -E '^card [0-9]+:' | grep -vi 'hdmi' | head -n1 || true)"
  fi
  if [[ -z "$line" ]]; then
    echo ""
    return 0
  fi
  # line format: card N: NAME [Desc], device ...
  local idx name
  idx="$(echo "$line" | awk '{print $2}' | tr -d ':')"
  name="$(echo "$line" | awk '{print $3}' | tr -d ':')"
  echo "${idx} ${name}"
}

DET="$(detect_card || true)"
ALSA_CARD_INDEX=""
ALSA_CARD_NAME=""
if [[ -n "$DET" ]]; then
  ALSA_CARD_INDEX="$(echo "$DET" | awk '{print $1}')"
  ALSA_CARD_NAME="$(echo "$DET" | awk '{print $2}')"
fi

if [[ -z "${ALSA_CARD_INDEX}" || -z "${ALSA_CARD_NAME}" ]]; then
  # Safe defaults (commonly: HDMI=0, seeed=1)
  ALSA_CARD_INDEX="1"
  ALSA_CARD_NAME="seeed2micvoicec"
  echo "WARN: Could not auto-detect ALSA card (may require reboot). Using defaults: card=${ALSA_CARD_INDEX}, name=${ALSA_CARD_NAME}"
fi

# Make HAT the default ALSA device (sysdefault -> HAT)
cat >/etc/asound.conf <<EOF
defaults.pcm.card ${ALSA_CARD_INDEX}
defaults.ctl.card ${ALSA_CARD_INDEX}
EOF

# Snapclient: explicitly target the working ALSA device; do NOT force sampleformat
cat >/etc/default/snapclient <<EOF
SNAPCLIENT_OPTS="--host ${SNAPSERVER_HOST} --port ${SNAPSERVER_PORT} --player alsa --device plughw:CARD=${ALSA_CARD_NAME},DEV=0"
EOF

systemctl enable --now snapclient || true

echo ""
echo "Configured:"
echo "  ALSA card index: ${ALSA_CARD_INDEX}"
echo "  ALSA card name : ${ALSA_CARD_NAME}"
echo "  snapclient     : plughw:CARD=${ALSA_CARD_NAME},DEV=0 -> ${SNAPSERVER_HOST}:${SNAPSERVER_PORT}"
echo ""
echo "Next: sudo reboot"
echo ""
echo "After reboot verify:"
echo "  aplay -l"
echo "  cat /proc/asound/cards"
echo "  speaker-test -D plughw:CARD=${ALSA_CARD_NAME},DEV=0 -r 48000 -c 2"
echo "  journalctl -u snapclient --since '2 minutes ago' --no-pager"
echo ""
echo "If the card name/index changes after reboot, run this one-liner to auto-fix configs:"
echo "  sudo bash -lc 'DET=\$(aplay -l | grep -E \"^card [0-9]+:\" | grep -Ei \"seeed|voicecard|wm8960\" | head -n1); \
IDX=\$(echo \"\$DET\" | awk \"{print \\$2}\" | tr -d \":\"); NAME=\$(echo \"\$DET\" | awk \"{print \\$3}\" | tr -d \":\"); \
printf \"defaults.pcm.card %s\\ndefaults.ctl.card %s\\n\" \"\$IDX\" \"\$IDX\" | tee /etc/asound.conf >/dev/null; \
printf \"SNAPCLIENT_OPTS=\\\"--host %s --port %s --player alsa --device plughw:CARD=%s,DEV=0\\\"\\n\" \"${SNAPSERVER_HOST}\" \"${SNAPSERVER_PORT}\" \"\$NAME\" | tee /etc/default/snapclient >/dev/null; \
systemctl reset-failed snapclient; systemctl restart snapclient; systemctl status snapclient --no-pager'"
