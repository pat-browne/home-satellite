# HAT_WALKTHROUGH.md - WM8960 (Seeed/ReSpeaker Mic HAT v1) on Pi Zero 2 W

## Goal

Install and validate a WM8960-based Seeed/ReSpeaker Mic HAT v1 on Raspberry Pi OS / Debian with the overlay that works on newer kernels.

## Why this approach

On newer Raspberry Pi kernels, older WM8960 overlays can enumerate but still fail playback (`No MCLK configured` / `hw_params -22`).

This repo pins to:

- `dtoverlay=respeaker-2mic-v1_0`
- built from `Seeed-Studio/seeed-linux-dtoverlays`

## 1) Run the HAT setup script

From repo root:

```bash
chmod +x seed_v1_hat/hat_audio_setup.sh
sudo ./seed_v1_hat/hat_audio_setup.sh
sudo reboot
```

## 2) Verify hardware + audio stack after reboot

```bash
aplay -l
cat /proc/asound/cards
sudo dtoverlay -l
sudo dmesg -T | egrep -i "wm8960|mclk|asoc|i2s|respeaker|seeed" | tail -n 120
speaker-test -D plughw:CARD=seeed2micvoicec,DEV=0 -r 48000 -c 2
```

Expected:

- Overlay list includes `respeaker-2mic-v1_0`
- ALSA shows a HAT card (typically `seeed2micvoicec`)
- Playback test produces left/right audio

## 3) Revert (if needed)

```bash
chmod +x seed_v1_hat/uninstall_hat_setup.sh
sudo ./seed_v1_hat/uninstall_hat_setup.sh
sudo reboot
```
