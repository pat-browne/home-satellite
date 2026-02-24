#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n==> $*\n"; }

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo SNAPSERVER_HOST=homeassistant.local $0"
  exit 1
fi

SNAPSERVER_HOST="${SNAPSERVER_HOST:-homeassistant.local}"
SNAPSERVER_PORT="${SNAPSERVER_PORT:-1704}"

log "Installing snapclient + time sync..."
apt-get update -y
apt-get install -y snapclient systemd-timesyncd alsa-utils

log "Detecting best ALSA playback device..."
# Prefer WM8960/voice/seeed/google cards; choose device 0
ALSA_CARD_NAME="$(aplay -l 2>/dev/null | awk '
  /^card [0-9]+:/ {
    # Example: card 0: seeed2micvoicec [seeed-2mic-voicecard], device 0: ...
    cardname=$3
    gsub(":", "", cardname)
    line=tolower($0)
    if (line ~ /(wm8960|voice|seeed|google)/) { print cardname; exit }
  }')"

if [[ -z "${ALSA_CARD_NAME:-}" ]]; then
  log "Could not auto-detect a WM8960/voice card. Falling back to 'default'."
  ALSA_DEVICE="default"
else
  ALSA_DEVICE="hw:CARD=${ALSA_CARD_NAME},DEV=0"
fi

log "Using Snapserver: ${SNAPSERVER_HOST}:${SNAPSERVER_PORT}"
log "Using ALSA device: ${ALSA_DEVICE}"

log "Creating systemd drop-in override for snapclient..."
mkdir -p /etc/systemd/system/snapclient.service.d

cat >/etc/systemd/system/snapclient.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/snapclient --logsink=system --host ${SNAPSERVER_HOST} --port ${SNAPSERVER_PORT} --player alsa --device ${ALSA_DEVICE}
EOF

log "Reloading systemd + restarting snapclient..."
systemctl daemon-reload
systemctl enable snapclient
systemctl reset-failed snapclient || true
systemctl restart snapclient

log "Snapcast client configured."
echo
echo "Verify:"
echo "  systemctl status snapclient --no-pager -l"
echo "  journalctl -u snapclient --since '2 minutes ago' --no-pager -l"
echo
echo "If snapclient starts but audio is silent, verify local audio first:"
echo "  speaker-test -D ${ALSA_DEVICE} -c 2 -r 48000"
