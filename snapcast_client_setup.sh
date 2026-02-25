#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n==> $*\n"; }
die() { echo -e "\nERROR: $*\n" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo SNAPSERVER_HOST=homeassistant.local $0"

SNAPSERVER_HOST="${SNAPSERVER_HOST:-homeassistant.local}"
SNAPSERVER_PORT="${SNAPSERVER_PORT:-1704}"

# Preferred card id for the WM8960 overlay we install.
PREFERRED_CARD_ID="seeed2micvoicec"

log "Installing snapclient + ALSA tools + time sync..."
apt-get update -y
apt-get install -y snapclient alsa-utils systemd-timesyncd

log "Ensuring time sync is active (Snapcast is sensitive to clock drift)..."
systemctl enable --now systemd-timesyncd >/dev/null 2>&1 || true

log "Ensuring _snapclient can access ALSA devices..."
getent group audio >/dev/null 2>&1 || groupadd -f audio
usermod -aG audio _snapclient || true

detect_card_index_by_id() {
  local id="$1"
  # /proc/asound/cards format includes: " 0 [seeed2micvoicec]: ..."
  awk -v id="$id" '
    $2 ~ /^\[/ {
      gsub(/[\[\]]/, "", $2)
      if ($2 == id) { print $1; exit }
    }
  ' /proc/asound/cards 2>/dev/null || true
}

detect_first_non_hdmi_card_id() {
  # Fallback: pick first card id not containing "hdmi"
  awk '
    $2 ~ /^\[/ {
      id=$2; gsub(/[\[\]]/, "", id)
      low=tolower(id)
      if (low !~ /hdmi/) { print id; exit }
    }
  ' /proc/asound/cards 2>/dev/null || true
}

log "Detecting ALSA card..."
CARD_ID=""
CARD_INDEX=""

if [[ -f /proc/asound/cards ]]; then
  CARD_INDEX="$(detect_card_index_by_id "$PREFERRED_CARD_ID")"
  if [[ -n "$CARD_INDEX" ]]; then
    CARD_ID="$PREFERRED_CARD_ID"
  else
    CARD_ID="$(detect_first_non_hdmi_card_id)"
    [[ -n "$CARD_ID" ]] || die "No ALSA cards found in /proc/asound/cards. Is the HAT configured + rebooted?"
    CARD_INDEX="$(detect_card_index_by_id "$CARD_ID")"
  fi
else
  die "/proc/asound/cards not found. ALSA not initialized?"
fi

log "Using ALSA card: id=${CARD_ID} index=${CARD_INDEX}"

# Force ALSA defaults to this card so 'default' doesn't drift to HDMI.
log "Writing /etc/asound.conf to pin default device to card ${CARD_INDEX}..."
cat >/etc/asound.conf <<EOF
defaults.pcm.card ${CARD_INDEX}
defaults.ctl.card ${CARD_INDEX}
EOF

# Prefer hw: for snapclient stability (we know 48k/16/2 matches server in your setup).
ALSA_DEVICE="hw:CARD=${CARD_ID},DEV=0"

log "Creating systemd drop-in override for snapclient ExecStart..."
mkdir -p /etc/systemd/system/snapclient.service.d
cat >/etc/systemd/system/snapclient.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/snapclient --logsink=system --host ${SNAPSERVER_HOST} --port ${SNAPSERVER_PORT} --player alsa --device ${ALSA_DEVICE}
EOF

log "Reloading systemd + restarting snapclient..."
systemctl daemon-reload
systemctl reset-failed snapclient || true
systemctl restart snapclient

log "Done."
echo "Verify:"
echo "  systemctl status snapclient --no-pager -l"
echo "  journalctl -u snapclient --since '2 minutes ago' --no-pager -l"
echo "  aplay -l"
echo "  cat /proc/asound/cards"
echo "  speaker-test -D plughw:CARD=${CARD_ID},DEV=0 -c 2 -r 48000"
