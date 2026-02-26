#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }

echo "==> Installing PipeWire + tools"
sudo apt-get update -y
sudo apt-get install -y \
  pipewire pipewire-audio-client-libraries pipewire-alsa pipewire-pulse \
  wireplumber pulseaudio-utils alsa-utils

echo "==> Enabling user services"
systemctl --user daemon-reload
systemctl --user enable --now pipewire pipewire-pulse wireplumber

echo "==> Enabling linger for user (so user services run after boot without interactive login)"
sudo loginctl enable-linger "$USER"

echo "==> Quick verification"
systemctl --user --no-pager --full status pipewire pipewire-pulse wireplumber | sed -n '1,14p' || true
echo
pactl info | egrep -i 'Server Name|Server String|Default Sink|Default Source' || true
echo
echo "Sinks:"
pactl list short sinks || true
echo "Sources:"
pactl list short sources || true
echo

# Try to pick WM8960 / Seeed sink/source automatically
pick_match() {
  local kind="$1"   # sinks|sources
  local pat='(seeed|wm8960|voicec|respeaker)'
  pactl "list short $kind" 2>/dev/null | awk -v IGNORECASE=1 -v pat="$pat" '$2 ~ pat {print $2; exit}'
}

SINK="$(pick_match sinks || true)"
SRC="$(pick_match sources || true)"

if [[ -n "${SINK:-}" ]]; then
  echo "==> Setting default sink to: $SINK"
  pactl set-default-sink "$SINK" || true
else
  echo "!! Could not auto-find a WM8960/Seeed sink name in pactl output."
  echo "   If ALSA shows seeed2micvoicec but pactl does not, PipeWire isn't discovering the card."
fi

if [[ -n "${SRC:-}" ]]; then
  echo "==> Setting default source to: $SRC"
  pactl set-default-source "$SRC" || true
fi

echo
echo "==> Audio test (PipeWire):"
if command -v pw-play >/dev/null 2>&1; then
  echo "Running: pw-play /usr/share/sounds/alsa/Front_Center.wav"
  pw-play /usr/share/sounds/alsa/Front_Center.wav || true
else
  echo "pw-play not found (unexpected)."
fi

echo
echo "==> Audio test (direct ALSA to WM8960):"
echo "Run this to confirm you can hear output via the HAT:"
echo "  speaker-test -D hw:CARD=seeed2micvoicec,DEV=0 -c 2 -t wav"
