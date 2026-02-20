#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo SNAPSERVER_HOST=homeassistant.local ./setup.sh
#   sudo SNAPSERVER_HOST=192.168.1.50 ./setup.sh
# Optional:
#   SNAPSERVER_PORT=1704 (default)
#   SNAPCLIENT_SAMPLEFORMAT=48000:16:2 (default)

SNAPSERVER_HOST="${SNAPSERVER_HOST:-homeassistant.local}"
SNAPSERVER_PORT="${SNAPSERVER_PORT:-1704}"
SNAPCLIENT_SAMPLEFORMAT="${SNAPCLIENT_SAMPLEFORMAT:-48000:16:2}"

CFG="/boot/firmware/config.txt"
CMD="/boot/firmware/cmdline.txt"
[[ -f "$CFG" ]] || CFG="/boot/config.txt"
[[ -f "$CMD" ]] || CMD="/boot/cmdline.txt"

apt-get update -y
apt-get install -y git dkms i2c-tools alsa-utils snapclient

cat >/etc/modules-load.d/i2c.conf <<'EOF'
i2c-dev
i2c-bcm2835
EOF

cp -a "$CFG" "$CFG.bak"
grep -q "seeed-voicecard block" "$CFG" || cat >>"$CFG" <<'EOF'

# --- seeed-voicecard block ---
dtparam=audio=off
dtparam=i2c_arm=on
dtoverlay=seeed-2mic-voicecard
# --- end seeed-voicecard block ---
EOF

if [[ -f "$CMD" ]]; then
  cp -a "$CMD" "$CMD.bak"
  sed -i \
    -e 's/\s*snd_bcm2835\.enable_headphones=[^ ]*//g' \
    -e 's/\s*snd_bcm2835\.enable_hdmi=[^ ]*//g' \
    -e 's/  */ /g; s/^ *//; s/ *$//' \
    "$CMD"
fi

WORK="/opt/seeed-voicecard"
[[ -d "$WORK/.git" ]] || git clone https://github.com/HinTak/seeed-voicecard "$WORK"
git -C "$WORK" fetch --all --prune
for b in "v$(uname -r | cut -d. -f1-2)" master; do
  git -C "$WORK" checkout -f "$b" 2>/dev/null && break
done
git -C "$WORK" pull --ff-only || true
(cd "$WORK" && ./install.sh)

cat >/etc/default/snapclient <<EOF
SNAPCLIENT_OPTS="--host ${SNAPSERVER_HOST} --port ${SNAPSERVER_PORT} --sampleformat ${SNAPCLIENT_SAMPLEFORMAT}"
EOF
systemctl enable --now snapclient

echo "OK. Reboot next: sudo reboot"
