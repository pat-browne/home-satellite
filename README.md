# home-satellite

Turn a Raspberry Pi Zero 2 W + ReSpeaker 2-Mic HAT v1 (WM8960) into a Home Assistant / Music Assistant satellite audio endpoint.

## Project structure

```text
home-satellite/
|- seed_v1_hat/        # WM8960 overlay install/uninstall + HAT walkthrough
|- snapcast_client/    # snapclient install/uninstall + snapcast walkthroughs
\- lvm_setup/          # optional PipeWire + Linux Voice Assistant setup
```

## Quick start

### 1) Clone

```bash
cd ~
git clone https://github.com/pat-browne/home-satellite.git
cd home-satellite
```

### 2) Install/enable HAT overlay (requires reboot)

```bash
chmod +x seed_v1_hat/hat_audio_setup.sh
sudo ./seed_v1_hat/hat_audio_setup.sh
sudo reboot
```

Verify after reboot:

```bash
aplay -l
cat /proc/asound/cards
sudo dmesg -T | egrep -i 'wm8960|mclk|asoc|i2s|respeaker|seeed' | tail -n 80
speaker-test -D plughw:CARD=seeed2micvoicec,DEV=0 -c 2 -r 48000
```

### 3) Install/configure snapclient

```bash
chmod +x snapcast_client/snapcast_client_setup.sh
sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client/snapcast_client_setup.sh
```

Verify:

```bash
systemctl status snapclient --no-pager -l
journalctl -u snapclient --since '2 minutes ago' --no-pager -l
```

## Optional: PipeWire + Linux Voice Assistant

Run from repo root:

```bash
chmod +x lvm_setup/setup_pipewire.sh lvm_setup/setup_lva_systemd.sh
./lvm_setup/setup_pipewire.sh
./lvm_setup/setup_lva_systemd.sh
```

## Uninstall scripts

- HAT revert: `seed_v1_hat/uninstall_hat_setup.sh`
- Snapclient revert: `snapcast_client/uninstall_snapcast.sh`

## Walkthrough docs

- HAT: `seed_v1_hat/HAT_WALKTHROUGH.md`
- Snapcast: `snapcast_client/WALKTHROUGH.md`
- LVA/PipeWire: `lvm_setup/README.md`
