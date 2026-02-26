#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing PipeWire stack"
sudo apt-get update -y
sudo apt-get install -y \
  pipewire pipewire-audio-client-libraries pipewire-alsa pipewire-pulse \
  wireplumber pulseaudio-utils alsa-utils

echo "==> Enabling linger (required for user services on boot)"
sudo loginctl enable-linger "$USER"

echo "==> Enabling PipeWire user services"
systemctl --user daemon-reload
systemctl --user enable --now pipewire pipewire-pulse wireplumber

echo "==> Quick verification"
systemctl --user --no-pager --full status pipewire pipewire-pulse wireplumber | sed -n '1,12p' || true
echo
pactl info | egrep -i 'Server Name|Server String|Default Sink|Default Source' || true
echo
echo "Sinks:"
pactl list short sinks || true
echo "Sources:"
pactl list short sources || true
echo
echo "Audio test (PipeWire): pw-play /usr/share/sounds/alsa/Front_Center.wav"
pw-play /usr/share/sounds/alsa/Front_Center.wav || true
echo
echo "Direct ALSA sanity test (WM8960/HAT):"
echo "  speaker-test -D hw:CARD=seeed2micvoicec,DEV=0 -c 2 -t wav"
