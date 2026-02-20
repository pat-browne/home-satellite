# Raspberry Pi Zero 2 W + Seeed/ReSpeaker Mic Hat v1 (WM8960) Audio Endpoint (Snapcast)

## Objective
Configure a Raspberry Pi Zero 2 W with a WM8960-based Seeed/ReSpeaker Mic Hat v1 to function as a stable audio endpoint suitable for whole-home audio (e.g., Snapcast client controlled by Home Assistant).

## Background (why these steps exist)
WM8960 HATs may appear on I2C and even instantiate an ALSA card while still failing playback due to codec clocking issues (commonly `No MCLK configured` and `hw_params -22`).  
The HinTak `seeed-voicecard` fork provides a known-good driver and overlay combination for newer kernels and mitigates this failure mode.

---

## 1) Flash OS

Recommended: **Raspberry Pi OS Lite (Bookworm)**.

- Enable SSH during imaging.
- Configure Wi-Fi during imaging if needed.

Boot the Pi and SSH in:

```bash
ssh pi@<pi-ip>
```

---

## 2) Run automated setup

Copy `setup.sh` to the Pi and run:

```bash
chmod +x setup.sh
sudo SNAPSERVER_HOST=homeassistant.local ./setup.sh
```

Or specify a static IP:

```bash
sudo SNAPSERVER_HOST=192.168.1.50 ./setup.sh
```

Optional environment variables:

- `SNAPSERVER_PORT` (default `1704`)
- `SNAPCLIENT_SAMPLEFORMAT` (default `48000:16:2`)

Reboot when the script finishes:

```bash
sudo reboot
```

---

## 3) Verification

### 3.1 I2C bus and codec presence

```bash
ls -l /dev/i2c* || true
sudo i2cdetect -y 1
```

Expected: a device typically at `0x1a` (WM8960).

---

### 3.2 ALSA sound card enumeration

```bash
cat /proc/asound/cards
aplay -l
```

Expected: a non-HDMI card such as `seeed2micvoicec` and optionally HDMI as another card.

---

### 3.3 Playback test (known-safe format)

```bash
speaker-test -D plughw:CARD=seeed2micvoicec,DEV=0 -r 48000 -c 2
```

If the card name differs, use the label shown by:

```bash
aplay -l
```

---

### 3.4 Snapclient service validation

```bash
systemctl status snapclient --no-pager
journalctl -u snapclient -n 50 --no-pager
```

Expected: snapclient is active and connected to the configured Snapserver host.

---

## 4) Common Fixes

### A) Only HDMI appears in `/proc/asound/cards`

Symptoms:
- `/proc/asound/cards` lists only `vc4hdmi`.

Actions:

1. Confirm the correct config file is used:
   - `/boot/firmware/config.txt` (modern images)
   - `/boot/config.txt` (older layouts)

2. Confirm these lines exist exactly once:

```
dtparam=audio=off
dtparam=i2c_arm=on
dtoverlay=seeed-2mic-voicecard
```

3. Verify I2C:

```bash
ls -l /dev/i2c* || true
sudo i2cdetect -y 1
```

---

### B) I2C devices missing (`/dev/i2c-1` not present)

Actions:

1. Confirm modules autoload:

```bash
cat /etc/modules-load.d/i2c.conf
```

Expected:

```
i2c-dev
i2c-bcm2835
```

2. Load immediately without reboot:

```bash
sudo modprobe i2c-dev
sudo modprobe i2c-bcm2835
ls -l /dev/i2c* || true
```

---

### C) Playback fails with `No MCLK configured` or `hw_params -22`

Cause:
Codec clocking mismatch with kernel overlay.

Actions:

1. Ensure HinTak `seeed-voicecard` is installed.
2. Confirm active overlay is:

```
dtoverlay=seeed-2mic-voicecard
```

3. Re-run installer if necessary:

```bash
sudo /opt/seeed-voicecard/install.sh
sudo reboot
```

---

### D) Snapclient running but no audible output

1. Confirm connection:

```bash
journalctl -u snapclient -n 50 --no-pager
```

2. Confirm sample format (48kHz / 16-bit / stereo recommended):

```bash
cat /etc/default/snapclient
```

3. Check mixer levels:

```bash
alsamixer
```

Select the WM8960/Seeed card (F6), unmute playback channels, raise volume.

---

## Notes

- `homeassistant.local` requires mDNS support on the network.  
  If unreliable, use a static IP.
- Snapclient is enabled as a systemd service and starts automatically on boot.
- Use `aplay -l` to confirm the exact ALSA card name when testing playback.
