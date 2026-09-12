# 04 · Volume Sync: master-slave loudness matching

> The official stereo explicitly states "volume sync is not supported". This document provides a complete solution.

> 🌐 [简体中文](04-volume-sync.md) | [English](04-volume-sync.en.md)

---

## 1. Why it's hard

| Difficulty | Cause |
|---|---|
| The audio stream carries no volume metadata | The master encodes and sends audio as-is |
| Different models, different loudness curves | The same value maps to different physical loudness (the interface floor values also differ) |
| ALSA softvol caches volume | softvol locks the value at PCM open; changing the control later doesn't follow AND disturbs the PCM stream |
| Asymmetric API units | `get` returns 0–255, `set` takes 0–100 (app slider value) |

## 2. Design

```
Master (LX06)                        Slave (OH2P)
┌──────────────────┐                ┌──────────────────────┐
│ vol_sync daemon   │    SSH (key)   │ vol_apply daemon      │
│ watches master    │ ──target──────▶ │ read target → hw      │
│ (push on change)  │                │ mixer Master (hw reg) │
└──────────────────┘                └──────────────────────┘
```

**Key decisions:**

1. **Volume action point = hardware mixer `Master`** (0–16)
   ALSA softvol caches the volume at PCM open; later changes don't follow and disturb the stream.
   The hardware register applies in real time without touching the PCM stream.

2. **Floor alignment**: both devices' volume interfaces have a floor value
   (setting 0 still yields internal 25), but internal=25 means silence on the master
   and a faint sound on the slave. The mapping aligns:
   `master's [25..255] → slave's Master [0..16]` — volume 0 = both truly silent.

3. **Push only on change**: the slave's own adjustment isn't overwritten by the master.

## 3. Installation

### 3.1 Set up master→slave SSH key auth

Both devices' dropbear reads authorized keys from `/etc/dropbear/authorized_keys`
(the global path, NOT `~/.ssh/`), and `/etc` is read-only, so use bind-mount:

```bash
# Master: generate key
ssh root@<LX06_IP> 'dropbearkey -t rsa -s 2048 -f /data/vol_id'
# Get public key
ssh root@<LX06_IP> 'dropbearkey -y -f /data/vol_id | grep "^ssh-"'
```

```bash
# Slave: backup original → append master pubkey → bind-mount
ssh root@<OH2P_IP> 'cp /etc/dropbear/authorized_keys /data/dropbear_authorized_keys'
ssh root@<OH2P_IP> 'echo "<master pubkey>" >> /data/dropbear_authorized_keys'
ssh root@<OH2P_IP> 'chmod 600 /data/dropbear_authorized_keys'
ssh root@<OH2P_IP> 'mount --bind /data/dropbear_authorized_keys /etc/dropbear/authorized_keys'
```

> ⚠️ dropbear 2017.75 supports RSA/DSS keys only (no ed25519).
> ⚠️ bind-mount doesn't survive reboot — it must be in the slave's init script
> (`init-slave.sh` already includes it).

### 3.2 Deploy daemons

```bash
scp scripts/vol_sync.sh  root@<LX06_IP>:/data/vol_sync.sh
scp scripts/vol_apply.sh root@<OH2P_IP>:/data/vol_apply.sh

# Both init-*.sh scripts auto-start them on boot
```

## 4. Loudness calibration

Different models have different loudness curves. `vol_apply.sh` provides a `CAL` factor:

```bash
CAL=100    # 100 = 1.0×. Slave too loud → decrease (e.g. 90); too quiet → increase (e.g. 110)
```

**Calibration method**: play the same song on both, set the master volume to mid-range,
compare loudness by ear, adjust CAL. (Each change requires a slave stereo restart
and one song switch — see the note in the stereo setup doc.)

## 5. Compiling stereo with the timeline-drift fix

Volume sync requires a stable stereo connection, but upstream stereo has the
timeline-drift bug. Apply the patch and recompile:

```bash
# Apply patch
cd open-xiaoai
git apply patches/master-timeline-drift-fix.patch

# Build (requires Docker Desktop running)
cd examples/stereo && make build
# Artifact: target/armv7-unknown-linux-gnueabihf/release/stereo
```

> 💡 On macOS Apple Silicon, pulling the image requires the platform flag:
> `docker pull --platform linux/amd64 <image>`
> Docker Hub direct connection may stall — use a registry mirror (e.g. `docker.1ms.run/` prefix).

Deploy the binary to both devices and restart.
