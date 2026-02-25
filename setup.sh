#!/usr/bin/env bash
set -euo pipefail

die() { echo -e "\nERROR: $*\n" >&2; exit 1; }
log() { echo -e "\n==> $*\n"; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo SNAPSERVER_HOST=homeassistant.local $0"

SNAPSERVER_HOST="${SNAPSERVER_HOST:-homeassistant.local}"
SNAPSERVER_PORT="${SNAPSERVER_PORT:-1704}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "Step 1/2: HAT (WM8960) overlay setup..."
bash "${SCRIPT_DIR}/hat_audio_setup.sh"

cat <<EOF

IMPORTANT:
  The HAT setup requires a reboot before audio playback is reliable.
  Reboot now, then run:

    cd ${SCRIPT_DIR}
    sudo SNAPSERVER_HOST=${SNAPSERVER_HOST} SNAPSERVER_PORT=${SNAPSERVER_PORT} ./snapcast_client_setup.sh

EOF
