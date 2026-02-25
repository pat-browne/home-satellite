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

### 1) Install/enable the HAT overlay (requires reboot)
```bash
cd ~
git clone https://github.com/pat-browne/home-satellite.git
cd home-satellite
chmod +x hat_audio_setup.sh snapcast_client_setup.sh 
sudo ./hat_audio_setup.sh
sudo reboot
```

verify after reboot:
```bash
aplay -l
sudo dmesg -T | egrep -i 'wm8960|mclk|asoc|i2s|respeaker|seeed' | tail -n 80
speaker-test -c 2 -r 48000
```

### 2) Install/configure snapclient
```bash
sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client_setup.sh
```

Verify:
```bash
systemctl status snapclient --no-pager -l
journalctl -u snapclient --since '2 minutes ago' --no-pager -l
```
