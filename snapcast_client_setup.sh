#!/usr/bin/env bash
set -euo pipefail

# Snapcast client setup for ReSpeaker 2-Mic HAT v1 satellites.
# Requires working audio first (no "No MCLK configured" in dmesg).

SNAPSERVER_HOST="${SNAPSERVER_HOST:-homeassistant.local}"
SNAPSERVER_PORT="${SNAPSERVER_PORT:-1704}"

# If set to 1, write /etc/asound.conf to make the HAT the system default.
SET_ASOUND_DEFAULT="${SET_ASOUND_DEFAULT:-0}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo SNAPSERVER_HOST=... $0"

echo "[1/7] Sanity checks..."
if sudo dmesg -T | grep -qi "No MCLK configured"; then
  die "Detected 'No MCLK configured' in dmesg. Fix HAT overlay first (use dtoverlay=respeaker-2mic-v1_0), reboot, then retry."
fi

echo "[2/7] Installing snapclient..."
apt-get update -y
apt-get install -y snapclient

echo "[3/7] Detecting ALSA card for the HAT..."
# Prefer explicit known card names first, then any non-HDMI card.
CARD_NAME="$(
  aplay -l 2>/dev/null | awk -F'[:, ]+' '
    $1=="card" {
      n=$3;
      if (n ~ /(seeed2micvoicec|respeaker|wm8960|seeed)/) { print n; exit }
      if (n !~ /(vc4hdmi|bcm2835)/) { cand=n }
    }
    END { if (cand!="") print cand }
  '
)"

[[ -n "${CARD_NAME:-}" ]] || die "Could not find an ALSA card. Is the HAT working? Try: aplay -l"

DEVICE="hw:CARD=${CARD_NAME},DEV=0"

echo "  Selected ALSA card: ${CARD_NAME}"
echo "  Device string     : ${DEVICE}"

echo "[4/7] Optional: set ALSA default to the HAT..."
if [[ "$SET_ASOUND_DEFAULT" == "1" ]]; then
  # Determine numeric card index from aplay -l "card X: <name>"
  CARD_INDEX="$(
    aplay -l 2>/dev/null | awk -v target="$CARD_NAME" -F'[:, ]+' '
      $1=="card" && $3==target { print $2; exit }
    '
  )"
  [[ -n "${CARD_INDEX:-}" ]] || die "Could not map card name to index. Try: aplay -l"
  cat >/etc/asound.conf <<EOF
defaults.pcm.card ${CARD_INDEX}
defaults.ctl.card ${CARD_INDEX}
EOF
  echo "  Wrote /etc/asound.conf defaults to card index ${CARD_INDEX}"
else
  echo "  Skipping /etc/asound.conf (SET_ASOUND_DEFAULT=0)"
fi

echo "[5/7] Writing systemd drop-in override for snapclient..."
DROPIN_DIR="/etc/systemd/system/snapclient.service.d"
DROPIN_FILE="${DROPIN_DIR}/override.conf"
mkdir -p "$DROPIN_DIR"

cat >"$DROPIN_FILE" <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/snapclient --logsink=system --host ${SNAPSERVER_HOST} --port ${SNAPSERVER_PORT} --player alsa --device ${DEVICE}
Restart=on-failure
RestartSec=2
EOF

echo "[6/7] Reloading systemd and restarting snapclient..."
systemctl daemon-reload
systemctl enable snapclient
systemctl reset-failed snapclient || true
systemctl restart snapclient

echo "[7/7] Done."
echo
echo "Snapcast client configured:"
echo "  Server : ${SNAPSERVER_HOST}:${SNAPSERVER_PORT}"
echo "  Device : ${DEVICE}"
echo
echo "Verify:"
echo "  systemctl status snapclient --no-pager -l"
echo "  journalctl -u snapclient --since '2 minutes ago' --no-pager -l"
echo
echo "If audio is silent, verify HAT output first:"
echo "  speaker-test -D ${DEVICE} -c 2 -r 48000"
