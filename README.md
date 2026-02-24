# home-satellite

Turnkey setup for Raspberry Pi “satellites” (Snapcast clients + audio HAT config seeed v1).

## Scripts

### 1) Audio HAT / Overlay Setup (WM8960 / voice HAT)
Runs the kernel-compatible dtoverlay configuration and ALSA defaults.

- Script: `hat_audio_setup.sh`

Usage:

```bash
sudo ./hat_audio_setup.sh
sudo reboot
```

### 2) Snapcast Client Install + Config

Installs snapclient and configures a systemd drop-in to use the detected ALSA device.

- Script: snapcast_client_setup.sh

Usage:

```bash
sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client_setup.sh
```

# Quickstart

Usage:
```bash
sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client_setup.sh
git clone https://github.com/pat-browne/home-satellite.git
cd home-satellite
chmod +x hat_audio_setup.sh snapcast_client_setup.sh
sudo ./hat_audio_setup.sh
sudo reboot
```

## after reboot:
```bash

sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client_setup.sh
```
---

## Why the “third party github drivers”
 **WM8960 HATs have a history of vendor overlays/drivers drifting behind kernel/device-tree changes**.
 People with WM8960 hats (not just Seeed) report the same “No MCLK configured” symptom on 6.12. :contentReference[oaicite:2]{index=2}

---
