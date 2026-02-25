# home-satellite

Turn a Raspberry Pi Zero 2 W + ReSpeaker 2-Mic HAT v1 (WM8960) into a Snapcast satellite speaker for Home Assistant / Music Assistant.

## Why this repo exists

Debian 13 (trixie) with Raspberry Pi kernel 6.12.x requires a device-tree overlay that provides WM8960 MCLK correctly.
Legacy overlays like `seeed-2mic-voicecard` or `googlevoicehat-soundcard` can trigger:

- `wm8960 ... No MCLK configured`
- ALSA `Can't set hardware parameters: Invalid argument`

This repo standardizes on the working overlay:

- `dtoverlay=respeaker-2mic-v1_0` built from `Seeed-Studio/seeed-linux-dtoverlays`

## Quick start

Clone:

```bash
cd ~
git clone https://github.com/pat-browne/home-satellite.git
cd home-satellite
