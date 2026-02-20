# home-satellite
home audio and AI assistant

# Pi WM8960 Satellite Audio Endpoint (Home Assistant + Snapcast)

This repo contains a turnkey setup for a Raspberry Pi Zero 2 W + WM8960-based Seeed/ReSpeaker Mic HAT v1 to act as a whole-home audio endpoint.

## What’s included

### 1) HAT (WM8960) setup
- Script: `hat_setup.sh`
- Guide : `HAT_WALKTHROUGH.md`

Installs HinTak `seeed-voicecard`, enables I2C, and configures the correct overlay.

### 2) Snapcast client setup
- Script: `snapcast_client_setup.sh`
- Guide : `SNAPCAST_WALKTHROUGH.md`

Installs and configures `snapclient` to connect to your Snapserver and pins output using `snapclient -s/--soundcard`.

## Quick start

```
cd ~ && rm -rf ~/home-satellite && \
git clone https://github.com/pat-browne/home-satellite.git && \
cd ~/home-satellite && \
chmod +x hat_setup.sh snapcast_client_setup.sh && \
sudo ./hat_setup.sh && \
sudo reboot
```
Then after reboot
```
cd ~/home-satellite && sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client_setup.sh
```

### Or Manually:

1) HAT setup:
```bash
chmod +x hat_setup.sh
sudo ./hat_setup.sh
sudo reboot
```

2) Snapcast client setup:
```bash
chmod +x snapcast_client_setup.sh
sudo SNAPSERVER_HOST=homeassistant.local ./snapcast_client_setup.sh
```

## Notes

homeassistant.local requires mDNS; use a static IP if unreliable.

Time sync is recommended for Snapcast synchronization (timedatectl status).


---

