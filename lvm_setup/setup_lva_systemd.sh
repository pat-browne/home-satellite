#!/usr/bin/env bash
set -euo pipefail

LVA_DIR="${LVA_DIR:-$HOME/linux-voice-assistant}"
LVA_PORT="${LVA_PORT:-6053}"

USER_ID="$(id -u)"
GROUP_ID="$(id -g)"
PULSE_SERVER="unix:/run/user/${USER_ID}/pulse/native"
XDG_RUNTIME_DIR="/run/user/${USER_ID}"

echo "==> Installing LVA prerequisites"
sudo apt-get update -y
sudo apt-get install -y \
  git jq curl wget vim \
  avahi-utils alsa-utils pulseaudio-utils \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  python3 python3-venv python3-dev \
  build-essential libmpv-dev libasound2-plugins

echo "==> Ensuring linger + PipeWire user services"
sudo loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now pipewire pipewire-pulse wireplumber

echo "==> Cloning/updating linux-voice-assistant"
if [[ -d "$LVA_DIR/.git" ]]; then
  git -C "$LVA_DIR" pull --ff-only
else
  git clone https://github.com/OHF-Voice/linux-voice-assistant.git "$LVA_DIR"
fi

echo "==> Running LVA setup"
cd "$LVA_DIR"
chmod +x docker-entrypoint.sh || true
if [[ -x script/setup ]]; then
  script/setup
else
  echo "!! script/setup not found; upstream layout may have changed."
  exit 1
fi

echo "==> Creating systemd service: /etc/systemd/system/linux-voice-assistant.service"
sudo tee /etc/systemd/system/linux-voice-assistant.service >/dev/null <<EOF
[Unit]
Description=Linux Voice Assistant
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${LVA_DIR}
Environment=LVA_PORT=${LVA_PORT}
Environment=LVA_PULSE_SERVER=${PULSE_SERVER}
Environment=LVA_XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
Environment=PYTHONUNBUFFERED=1
ExecStart=${LVA_DIR}/script/run
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

echo "==> Enabling + starting LVA"
sudo systemctl daemon-reload
sudo systemctl enable --now linux-voice-assistant.service

echo
echo "==> Quick verification"
sudo systemctl --no-pager --full status linux-voice-assistant.service | sed -n '1,18p' || true
echo
echo "Logs:"
echo "  sudo journalctl -u linux-voice-assistant -b --no-pager | tail -120"
echo
echo "HA pairing: ESPHome -> <pi-ip>:${LVA_PORT}"
