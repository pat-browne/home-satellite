#!/usr/bin/env bash
set -euo pipefail

# Snapcast client setup for the Pi audio endpoint.
# Key: snapclient v0.31 uses -s/--soundcard to select the ALSA card (not --device on many builds).
#
# Usage:
#   sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client_setup.sh
#   sudo SNAPSERVER_HOST=192.168.0.87 ./snapcast_client_setup.sh
#
# Optional:
#   SNAPSERVER_PORT=1704 (default)
#   SOUNDCARD_HINT=seeed|voicecard|wm8960 (default)
#   SOUNDCARD_NAME=seeed2micvoicec (optional hard override)

SNAPSERVER_HOST="${SNAPSERVER_HOST:-homeassistant.local}"
SNAPSERVER_PORT="${SNAPSERVER_PORT:-1704}"
SOUNDCARD_HINT="${SOUNDCARD_HINT:-seeed|voicecard|wm8960}"
SOUNDCARD_NAME="${SOUNDCARD_NAME:-}"

apt-get update -y
apt-get install -y snapclient

# Time sync matters for Snapcast A/V sync and latency calculations
apt-get install -y systemd-timesyncd || true
timedatectl set-ntp true || true

# Ensure snapclient service user can access ALSA
getent group audio >/dev/null && usermod -aG audio _snapclient 2>/dev/null || true

detect_soundcard() {
  # Prefer seeed/voicecard/wm8960
  local line
  line="$(aplay -l 2>/dev/null | grep -E '^card [0-9]+:' | grep -Ei "${SOUNDCARD_HINT}" | head -n1 || true)"
  if [[ -z "$line" ]]; then
    # fallback: first non-HDMI card
    line="$(aplay -l 2>/dev/null | grep -E '^card [0-9]+:' | grep -vi 'hdmi' | head -n1 || true)"
  fi
  [[ -n "$line" ]] || return 1
  echo "$line" | awk '{print $3}' | tr -d ':'
}

if [[ -z "$SOUNDCARD_NAME" ]]; then
  SOUNDCARD_NAME="$(detect_soundcard || true)"
fi

if [[ -z "$SOUNDCARD_NAME" ]]; then
  echo "ERROR: Could not detect an ALSA soundcard. Run: aplay -l"
  echo "If the HAT is installed, reboot once, then re-run this script."
  exit 1
fi

# Systemd override: pin snapclient to the soundcard using -s (modern, correct selector).
mkdir -p /etc/systemd/system/snapclient.service.d
cat >/etc/systemd/system/snapclient.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/snapclient --logsink=system -h ${SNAPSERVER_HOST} -p ${SNAPSERVER_PORT} --player alsa -s ${SOUNDCARD_NAME}
EOF

systemctl daemon-reload
systemctl enable snapclient
systemctl reset-failed snapclient || true
systemctl restart snapclient

echo ""
echo "Snapcast client configured:"
echo "  Server : ${SNAPSERVER_HOST}:${SNAPSERVER_PORT}"
echo "  Card   : ${SOUNDCARD_NAME} (via snapclient -s)"
echo ""
echo "Verify:"
echo "  systemctl status snapclient --no-pager -l"
echo "  journalctl -u snapclient --since '2 minutes ago' --no-pager -l"
echo "  timedatectl status | sed -n '1,20p'"
