# HAT_WALKTHROUGH.md — WM8960 (Seeed/ReSpeaker Mic HAT v1) on Pi Zero 2 W

## Goal
Install and validate a WM8960-based Seeed/ReSpeaker Mic HAT v1 on a Raspberry Pi Zero 2 W running Raspberry Pi OS Lite (Bookworm).

## Why this approach
Generic WM8960 overlays can instantiate an ALSA card while still failing playback on newer kernels due to clocking issues (`No MCLK configured` / `hw_params -22`). HinTak’s `seeed-voicecard` provides a known-good overlay/driver combination for modern kernels.

---

## 1) Flash OS
Recommended: Raspberry Pi OS Lite (Bookworm).

- Enable SSH during imaging.
- Configure Wi-Fi during imaging if needed.

SSH in:
```bash
ssh pi@<pi-ip>
```

---

## 2) Run the HAT setup script
Copy `hat_setup.sh` to the Pi, then:
```bash
chmod +x hat_setup.sh
sudo ./hat_setup.sh
sudo reboot
```

---

## 3) Verify hardware + audio stack

### 3.1 I2C bus and codec presence
```bash
ls -l /dev/i2c* || true
sudo i2cdetect -y 1
```
Expected: an address typically at `0x1a` (WM8960).

### 3.2 ALSA card enumeration
```bash
aplay -l
cat /proc/asound/cards
```
Expected: a card like `seeed2micvoicec` (name may vary).

### 3.3 Playback test (bypass Snapcast)
```bash
speaker-test -D plughw:CARD=seeed2micvoicec,DEV=0 -r 48000 -c 2
```
If the card name differs, use the `CARD=` label shown in `aplay -l`.

---

## Common fixes

### Only HDMI appears
- Confirm overlay lines exist in the active boot config:
  - `/boot/firmware/config.txt` (typical)
  - `/boot/config.txt` (older layouts)

Required lines:
```ini
dtparam=audio=off
dtparam=i2c_arm=on
dtoverlay=seeed-2mic-voicecard
```

Re-run installer:
```bash
sudo /opt/seeed-voicecard/install.sh
sudo reboot
```

### I2C missing (`/dev/i2c-1` absent)
```bash
cat /etc/modules-load.d/i2c.conf
sudo modprobe i2c-dev
sudo modprobe i2c-bcm2835
```

### Playback fails with MCLK / hw_params errors
Re-run HinTak installer + reboot:
```bash
sudo /opt/seeed-voicecard/install.sh
sudo reboot
```
