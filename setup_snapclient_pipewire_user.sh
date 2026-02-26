#!/usr/bin/env bash
set -euo pipefail

HOST="${SNAPSERVER_HOST:-homeassistant.local}"
PORT="${SNAPSERVER_PORT:-1704}"

echo "==> Ensuring snapclient is installed"
sudo apt-get update -y
sudo apt-get install -y snapclient pulseaudio-utils

echo "==> Enabling linger (user service must run after boot)"
sudo loginctl enable-linger "$USER"

echo "==> Disabling system snapclient service (prevents Pulse connect failures & conflicts)"
sudo systemctl disable --now snapclient 2>/dev/null || true
# Remove any overrides that might keep biting us
sudo rm -f /etc/systemd/system/snapclient.service.d/override.conf 2>/dev/null || true
sudo rmdir --ignore-fail-on-non-empty /etc/systemd/system/snapclient.service.d 2>/dev/null || true
sudo systemctl daemon-reload

echo "==> Creating user snapclient service (PipeWire/Pulse)"
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/snapclient.service <<EOF
[Unit]
Description=Snapclient (PipeWire/Pulse user service)
After=pipewire-pulse.service wireplumber.service
Wants=pipewire-pulse.service wireplumber.service

[Service]
Type=simple
Environment=PULSE_SERVER=unix:%t/pulse/native
ExecStart=/usr/bin/snapclient --logsink=system --host ${HOST} --port ${PORT} --player pulse
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

echo "==> Enabling snapclient user service"
systemctl --user daemon-reload
systemctl --user enable --now snapclient

echo "==> Quick verification"
systemctl --user --no-pager --full status snapclient | sed -n '1,14p' || true
echo
echo "If Snapcast is currently playing audio, snapclient should appear here:"
echo "  pactl list sink-inputs"
echo
echo "Logs:"
echo "  journalctl --user -u snapclient -b --no-pager | tail -80"
