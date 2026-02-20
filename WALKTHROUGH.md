# Raspberry Pi Zero 2 W + Seeed/ReSpeaker Mic Hat v1 (WM8960) Audio Endpoint (Snapcast)

## Objective
Configure a Raspberry Pi Zero 2 W with a WM8960-based Seeed/ReSpeaker Mic Hat v1 to function as a stable audio endpoint for whole-home audio using Snapcast (snapclient). Intended for use alongside Home Assistant (Snapserver running on HA host or another machine).

## Background (why these steps exist)
WM8960 HATs can appear on I2C and even instantiate an ALSA card while still failing playback due to codec clocking issues (commonly `No MCLK configured` and `hw_params -22`).  
HinTak’s `seeed-voicecard` fork provides a known-good driver and overlay combination for newer kernels and resolves the clocking/playback failure that can occur with generic overlays.

Additionally, snapclient defaults to `sysdefault` which may map to HDMI or an incompatible PCM device. This setup pins snapclient to a known-working ALSA device (`plughw:CARD=seeed2micvoicec,DEV=0`) and optionally maps `sysdefault` to the HAT via `/etc/asound.conf`.

---

## 1) Flash OS
Recommended: **Raspberry Pi OS Lite (Bookworm)**.

- Enable SSH during imaging.
- Configure Wi-Fi during imaging if needed.

Boot and SSH in:

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
sudo SNAPSERVER_HOST=192.168.0.87 ./setup.sh
```

Optional environment variables (rarely needed):
- `SNAPSERVER_PORT` (default `1704`)
- `ALSA_CARD_INDEX` (default `1`)
- `ALSA_CARD_NAME` (default `seeed2micvoicec`)

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

### 3.2 ALSA sound card enumeration
```bash
cat /proc/asound/cards
aplay -l
```
Expected: a card like `seeed2micvoicec` and optionally HDMI as another card.

### 3.3 Playback test (known-safe format)
```bash
speaker-test -D plughw:CARD=seeed2micvoicec,DEV=0 -r 48000 -c 2
```
If the card name differs, use the label shown by `aplay -l`.

### 3.4 Snapclient service validation
```bash
systemctl status snapclient --no-pager
journalctl -u snapclient --since "2 minutes ago" --no-pager
```
Expected: snapclient is active/running and connected to the configured Snapserver host, with no ALSA open errors.

---

## 4) Common fixes

### A) Only HDMI appears in `/proc/asound/cards`
Symptoms:
- `/proc/asound/cards` lists only `vc4hdmi`.

Actions:
1. Confirm the correct config file is used:
   - `/boot/firmware/config.txt` (modern installs)
   - `/boot/config.txt` (older layouts)

2. Confirm these lines exist (exactly once):
```ini
dtparam=audio=off
dtparam=i2c_arm=on
dtoverlay=seeed-2mic-voicecard
```

3. Verify I2C:
```bash
ls -l /dev/i2c* || true
sudo i2cdetect -y 1
```

4. Re-run installer:
```bash
sudo /opt/seeed-voicecard/install.sh
sudo reboot
```

### B) I2C devices missing (`/dev/i2c-1` not present)
Actions:
1. Confirm modules autoload:
```bash
cat /etc/modules-load.d/i2c.conf
```
Expected:
```text
i2c-dev
i2c-bcm2835
```

2. Load immediately (no reboot required):
```bash
sudo modprobe i2c-dev
sudo modprobe i2c-bcm2835
ls -l /dev/i2c* || true
```

### C) Playback fails with `No MCLK configured` / `hw_params -22`
Cause:
Codec clocking mismatch (common with generic WM8960 overlays on newer kernels).

Actions:
1. Ensure HinTak `seeed-voicecard` is installed:
```bash
sudo /opt/seeed-voicecard/install.sh
sudo reboot
```

2. Confirm the Seeed card is present:
```bash
cat /proc/asound/cards
dmesg | egrep -i "wm8960|asoc|snd_soc|mclk" | tail -n 120
```

### D) Snapclient running but no audible output (or ALSA errors like `-524`)
Cause:
snapclient may default to `sysdefault`, which can map to an incompatible PCM device.

Actions:
1. Confirm snapclient is targeting the HAT explicitly:
```bash
cat /etc/default/snapclient
```
Expected to include something like:
```text
--device plughw:CARD=seeed2micvoicec,DEV=0
```

2. If snapclient logs show it is using `sysdefault`, force the default ALSA card:
```bash
cat /etc/asound.conf
```
Example (card index may differ):
```text
defaults.pcm.card 1
defaults.ctl.card 1
```

3. Restart snapclient:
```bash
sudo systemctl reset-failed snapclient
sudo systemctl restart snapclient
journalctl -u snapclient --since "2 minutes ago" --no-pager
```

---

## Notes
- `homeassistant.local` requires mDNS. If it is unreliable, use a static IP.
- snapclient is enabled as a systemd service and starts automatically on boot.
- `aplay -l` is the source of truth for ALSA card indices/names on the device.
