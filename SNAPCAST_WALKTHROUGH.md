# SNAPCAST_WALKTHROUGH.md — Snapcast Client on Pi Audio Endpoint

## Goal
Install and configure a Snapcast client (snapclient) on a Raspberry Pi audio endpoint so it appears as a castable device (e.g., in Music Assistant) and plays through the WM8960 HAT.

## Important implementation detail (Snapclient selector)
On current Snapcast builds (e.g., snapclient v0.31.0), ALSA output selection is performed with:
- `-s, --soundcard <index|name>`

This is more reliable than attempting to pass raw ALSA PCM strings. The working approach is to pin the soundcard name discovered via `aplay -l`.

---

## 1) Prerequisites
- WM8960 HAT installed and working (`aplay -l` shows the HAT).
- Snapserver is reachable at `homeassistant.local:1704` (or a static IP).

---

## 2) Run the Snapcast client setup script
Copy `snapcast_client_setup.sh` to the Pi:

```bash
chmod +x snapcast_client_setup.sh
sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client_setup.sh
```

Or use a static IP:

```bash
sudo SNAPSERVER_HOST=192.168.0.87 ./snapcast_client_setup.sh
```

---

## 3) Verify snapclient and correct audio device selection

### 3.1 Confirm snapclient is running
```bash
systemctl status snapclient --no-pager -l
```

### 3.2 Confirm snapclient is using the WM8960 card
```bash
journalctl -u snapclient --since "2 minutes ago" --no-pager -l
```

Expected lines include:
- `Player name: alsa`
- `device: hw:CARD=<your_hat_card>,DEV=0`
- No `default:CARD=vc4hdmi` fallback
- No `Unknown error 524`

### 3.3 Confirm time sync (recommended)
Large clock drift can impact Snapcast sync behavior.
```bash
timedatectl status
```
Expected:
- `System clock synchronized: yes`

---

## Common fixes

### snapclient falls back to HDMI (`default:CARD=vc4hdmi`)
- Ensure the service is configured to use `-s <soundcard>` (not default).
- Re-run the setup script or inspect the override:

```bash
systemctl cat snapclient
cat /etc/systemd/system/snapclient.service.d/override.conf
aplay -l
```

### snapclient starts but closes ALSA when idle
Logs may show:
- `No chunks available`
- `No chunk received ... Closing ALSA`

This is normal when Snapserver is idle (no audio being streamed). Start playback from the server side to validate continuous audio.

### No sound during playback
- Confirm HAT plays via direct test:
```bash
speaker-test -D plughw:CARD=<hat_card>,DEV=0 -r 48000 -c 2
```
- Check mixer:
```bash
alsamixer
```
Select the WM8960 card (F6), unmute, increase volume.

### Service user access
snapclient runs as `_snapclient`. Ensure it has audio group access:
```bash
sudo usermod -aG audio _snapclient
sudo systemctl restart snapclient
```
