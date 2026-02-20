#!/usr/bin/env bash
set -euo pipefail

# HAT setup for WM8960-based Seeed/ReSpeaker Mic HAT v1 on Raspberry Pi OS
# - Installs HinTak/seeed-voicecard (modern kernel compatibility)
# - Enables I2C modules across reboots
# - Adds dtoverlay=seeed-2mic-voicecard
#
# Usage:
#   sudo ./hat_setup.sh

CFG="/boot/firmware/config.txt"
CMD="/boot/firmware/cmdline.txt"
[[ -f "$CFG" ]] || CFG="/boot/config.txt"
[[ -f "$CMD" ]] || CMD="/boot/cmdline.txt"

apt-get update -y
apt-get install -y git dkms i2c-tools alsa-utils device-tree-compiler

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

# Remove legacy bcm2835 cmdline flags that can interfere with audio routing
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

# Prefer a branch matching kernel major.minor (e.g., v6.12), otherwise master.
KVER_MM="v$(uname -r | cut -d. -f1-2)"
git -C "$WORK" checkout -f "$KVER_MM" 2>/dev/null || git -C "$WORK" checkout -f master
git -C "$WORK" pull --ff-only || true
(cd "$WORK" && ./install.sh)

echo ""
echo "HAT setup complete."
echo "Reboot next: sudo reboot"
echo ""
echo "After reboot verify:"
echo "  sudo i2cdetect -y 1        # should show 0x1a"
echo "  aplay -l                   # should show seeed2micvoicec (or similar)"
echo "  cat /proc/asound/cards"
