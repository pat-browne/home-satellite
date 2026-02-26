# Home Satellite – Voice Assistant Setup

Raspberry Pi Zero 2 W  
Debian 13 (trixie)  
Kernel 6.12.x (rpt)  
ReSpeaker 2-Mic HAT v1 (WM8960)

This adds **PipeWire + Linux Voice Assistant (LVA)** on top of the known-good Snapcast + WM8960 setup.

---

## Critical Overlay Requirement (Do Not Regress)

On kernel 6.12.x you **must** use:

```ini
dtparam=i2s=on
dtoverlay=respeaker-2mic-v1_0
dtparam=audio=off
```

Never use:
- `seeed-2mic-voicecard`
- `googlevoicehat-soundcard`
- old DKMS voicecard installs

Reboot after applying overlay changes.

Verify:

```bash
sudo dtoverlay -l
aplay -l
```

You should see:

```
respeaker-2mic-v1_0
seeed2micvoicec
```

---

# 1️ Install PipeWire

```bash
chmod +x setup_pipewire.sh
./setup_pipewire.sh
```

This script:

- Installs PipeWire + pipewire-pulse
- Enables user services
- Enables lingering (runs after reboot without login)
- Attempts to auto-select WM8960 as default
- Plays a short audio test

---

# 2️ Install Linux Voice Assistant (Systemd)

```bash
chmod +x setup_lva_systemd.sh
./setup_lva_systemd.sh
```

This script:

- Installs LVA prerequisites
- Clones/updates LVA
- Runs LVA setup
- Creates a systemd service
- Auto-detects WM8960 input/output if visible
- Starts LVA on port 6053

---

# 3️ Pair with Home Assistant

Add **ESPHome integration** and point to:

```
<pi-ip>:6053
```

---

# 🔍 Sanity Checks

## A. Confirm WM8960 Hardware (ALSA direct)

```bash
aplay -l | grep -i seeed
```

Test audio (bypasses PipeWire):

```bash
speaker-test -D hw:CARD=seeed2micvoicec,DEV=0 -c 2 -t wav
```

You must hear “front left / front right”.

If this fails → overlay problem (not PipeWire).

---

## B. Confirm PipeWire Running

```bash
pactl info
```

Expected:

```
Server Name: PulseAudio (on PipeWire ...)
Server String: /run/user/1000/pulse/native
```

List sinks/sources:

```bash
pactl list short sinks
pactl list short sources
```

You want to see something matching:

```
seeed
wm8960
voicec
respeaker
```

If PipeWire does not show the WM8960 sink but ALSA does → discovery issue.

---

## C. Test Audio Through PipeWire

```bash
pw-play /usr/share/sounds/alsa/Front_Center.wav
```

If sound works via `speaker-test` but not `pw-play` → default sink misconfigured.

---

## D. LVA Service Health

```bash
sudo systemctl status linux-voice-assistant
sudo journalctl -u linux-voice-assistant -f
```
