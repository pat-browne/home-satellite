#!/usr/bin/env bash
set -euo pipefail

LVA_DIR="${LVA_DIR:-$HOME/linux-voice-assistant}"
LVA_PORT="${LVA_PORT:-6053}"

# These match what you saw in:
#   pactl list short sources
#   ./script/run --list-output-devices
AUDIO_IN="${AUDIO_IN:-alsa_input.platform-soc_sound.stereo-fallback}"
AUDIO_OUT="${AUDIO_OUT:-pipewire/alsa_output.platform-soc_sound.stereo-fallback}"

WAKE_DIR="${LVA_DIR}/wakewords"
WAKE_MODEL="${WAKE_MODEL:-okay_nabu}"
STOP_MODEL="${STOP_MODEL:-stop}"

SERVICE_PATH="${HOME}/.config/systemd/user/linux-voice-assistant.service"

echo "[1/8] Install required packages (mpv is REQUIRED for playback)"
sudo apt-get update -y
sudo apt-get install -y mpv alsa-utils
sudo apt-get install -y \
  git jq curl wget vim \
  avahi-utils pulseaudio-utils \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  python3 python3-venv python3-dev \
  build-essential libmpv-dev libasound2-plugins

echo "[2/8] Set ALSA mixer volume to 80% (best-effort across common control names)"
# Control names vary by card/driver; try common ones and ignore failures.
sudo amixer -c 0 sset 'Headphone' 80% unmute 2>/dev/null || true
sudo amixer -c 0 sset 'Speaker'   80% unmute 2>/dev/null || true
sudo amixer -c 0 sset 'Master'    80% unmute 2>/dev/null || true
sudo amixer -c 0 sset 'PCM'       80% unmute 2>/dev/null || true

echo "[3/8] Enable linger so user service runs without interactive login"
sudo loginctl enable-linger "$USER"

echo "[4/8] Ensure PipeWire user services are enabled"
systemctl --user daemon-reload
systemctl --user enable --now pipewire pipewire-pulse wireplumber

echo "[5/8] Clone/update linux-voice-assistant"
if [[ -d "$LVA_DIR/.git" ]]; then
  git -C "$LVA_DIR" pull --ff-only
else
  git clone https://github.com/OHF-Voice/linux-voice-assistant.git "$LVA_DIR"
fi

echo "[6/8] Run LVA setup"
cd "$LVA_DIR"
chmod +x docker-entrypoint.sh || true
if [[ -x script/setup ]]; then
  script/setup
else
  echo "ERROR: script/setup not found in ${LVA_DIR}."
  exit 1
fi

echo "[7/8] Create/overwrite systemd user unit: ${SERVICE_PATH}"
mkdir -p "$(dirname "$SERVICE_PATH")"

cat > "$SERVICE_PATH" <<UNIT
[Unit]
Description=Linux Voice Assistant (user)
After=pipewire.service wireplumber.service
Wants=pipewire.service wireplumber.service

# NOTE: StartLimit* belongs in [Unit] on many systems; keep it here if you want it.
StartLimitIntervalSec=60
StartLimitBurst=10

[Service]
Type=simple
WorkingDirectory=${LVA_DIR}
Environment=PYTHONUNBUFFERED=1
Environment=LVA_PORT=${LVA_PORT}
Environment=XDG_RUNTIME_DIR=/run/user/%U
Environment=PULSE_SERVER=unix:/run/user/%U/pulse/native

# Run LVA directly (no bash -lc quoting issues)
ExecStart=${LVA_DIR}/script/run --debug --audio-input-device=${AUDIO_IN} --audio-output-device=${AUDIO_OUT} --wake-word-dir=${WAKE_DIR} --wake-model=${WAKE_MODEL} --stop-model=${STOP_MODEL} --refractory-seconds=2

Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
UNIT

echo "[8/8] Reload + enable + restart service"
systemctl --user daemon-reload
systemctl --user enable --now linux-voice-assistant.service
systemctl --user restart linux-voice-assistant.service

echo "Show status"
systemctl --user status linux-voice-assistant.service --no-pager

echo "Tail logs"
journalctl --user -u linux-voice-assistant -b --no-pager | tail -80

echo "Done."
echo "If you ever change devices, update AUDIO_IN/AUDIO_OUT at top of this script."
echo "HA pairing: ESPHome -> <pi-ip>:${LVA_PORT}"
