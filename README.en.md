# XiaoAI Stereo Duo

> Turn two different Xiaomi AI speakers into a true wireless Hi-Fi stereo pair.
> Left channel on the master, right channel on the slave — channel splitting done in code, not "two speakers playing the same song".

> 🌐 [简体中文](README.md) | [English](README.en.md) | [🤖 Agent 快速开始](AGENT_QUICKSTART.md) | [🤖 Agent Quick Start](AGENT_QUICKSTART.en.md)

## ✨ Why this project

| Highlight | Details |
|---|---|
| 🎵 **True stereo** | Intercepts system audio at the ALSA layer and **splits left/right channels per sample in code**: left plays locally, right is Opus-encoded and streamed to the slave in real time. Not "two speakers playing the same song" |
| 🔀 **Cross-model pairing** | XiaoAI Speaker Pro (LX06) + Xiaomi Smart Speaker Pro (OH2P) — two different generations with different firmware |
| 🛠 **Fixes upstream timeline-drift bug** | The official stereo computes playback time from "stream start + frame count". Any playback stall accumulates drift, and the slave drops all packets as "late" → silence. Our patch auto-realigns the timeline with the real clock — **auto-recovery after pause/resume/stutter** (see [patches/](patches/)) |
| 🔊 **Master-slave volume sync** | Officially "not supported". Implemented via master-side push + slave-side hardware mixer write — volume 0 = both speakers truly silent |
| 📦 **New OH2P firmware support** | Official prebuilt patch firmware only covers older versions. This project provides the full build process for OH2P 1.62.2 custom firmware |
| 🚀 **Survives power cycle** | Everything auto-starts on boot; stereo reconnects automatically after power loss |

## 📦 Supported hardware

| Device | Model | Role | Flashing |
|---|---|---|---|
| XiaoAI Speaker Pro | LX06 | Master (left channel + audio source) | Teardown + Micro USB ([guide](docs/02-flash-lx06.en.md)) |
| Xiaomi Smart Speaker Pro | OH2P | Slave (right channel) | Type-C, no teardown ([guide](docs/01-flash-oh2p.en.md)) |

## 🏗 How it works

```
                    ┌─────────────────────────────────┐
   Mi Home / BT     │  LX06 (Master · Left)            │
        │           │                                 │
        ▼           │  mediaplayer                    │
   Xiaomi Music      │      │ ALSA redirect            │
        │           │      ▼                         │
        └──────────▶│  /tmp/stereo_out.fifo          │
                    │      │                         │
                    │      ▼                         │
                    │  stereo (master)                │
                    │   ├─ Split: L → local playback  │
                    │   └─ R → Opus encode            │
                    │           │ UDP :53531          │
                    └───────────┼─────────────────────┘
                                │ LAN
                                ▼
                    ┌─────────────────────────────────┐
                    │  OH2P (Slave · Right)            │
                    │                                 │
                    │  stereo (slave)                  │
                    │   ├─ Receive → decode → play R   │
                    │   └─ Clock sync (NTP+Kalman)     │
                    │                                 │
                    │  vol_apply daemon                │
                    │   └─ volume → hw mixer Master    │
                    └─────────────────────────────────┘
```

**Volume sync**: when the master's volume changes, it pushes the target to the slave; the slave's daemon writes it to the hardware mixer (bypassing ALSA softvol, which caches volume and disturbs the PCM stream).

## 🚀 Quick start

> Prerequisite: both speakers are flashed with patched firmware and reachable via SSH.
> For flashing, read in order: [OH2P flashing](docs/01-flash-oh2p.en.md) → [LX06 flashing](docs/02-flash-lx06.en.md)

### 1. Configure master/slave roles

```bash
# Master (LX06)
ssh root@<LX06_IP> 'mkdir -p /data/open-xiaoai && echo "master left" > /data/open-xiaoai/stereo.conf'

# Slave (OH2P)
ssh root@<OH2P_IP> 'mkdir -p /data/open-xiaoai && echo "slave right" > /data/open-xiaoai/stereo.conf'
```

### 2. Install the stereo service

```bash
# On both devices
curl -sSfL https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/init.sh | sh
```

### 3. Apply this project's patches & scripts

```bash
# Slave (OH2P) — audio chain bypass + amp activation + volume daemon
scp scripts/init-slave.sh root@<OH2P_IP>:/data/init.sh

# Master (LX06) — volume sync daemon
scp scripts/init-master.sh root@<LX06_IP>:/data/init.sh
scp scripts/vol_sync.sh root@<LX06_IP>:/data/vol_sync.sh
scp scripts/vol_apply.sh root@<OH2P_IP>:/data/vol_apply.sh

# Reboot both
ssh root@<LX06_IP> reboot && ssh root@<OH2P_IP> reboot
```

### 4. Enjoy stereo

Play any audio via Mi Home / Bluetooth / XiaoAI — channels split automatically.

## 📁 Project structure

```
├── README.md / README.en.md
├── AGENT_QUICKSTART.md / AGENT_QUICKSTART.en.md   # For AI agents
├── docs/
│   ├── 00-check-firmware.md(.en)   # Firmware version check
│   ├── 01-flash-oh2p.md(.en)       # OH2P flashing + custom firmware build
│   ├── 02-flash-lx06.md(.en)       # LX06 flashing (teardown)
│   ├── 03-stereo-setup.md(.en)     # Stereo setup & verification
│   └── 04-volume-sync.md(.en)      # Volume sync theory & install
├── patches/
│   └── master-timeline-drift-fix.patch
├── scripts/                        # Working scripts from the devices
└── firmware/                       # (empty) Build your own or grab from Releases
```

## 📖 Detailed docs

- [OH2P flashing guide](docs/01-flash-oh2p.en.md) — includes 1.62.2 custom firmware build
- [LX06 flashing guide](docs/02-flash-lx06.en.md) — teardown, debug port, connection tricks
- [Stereo setup](docs/03-stereo-setup.en.md) — roles, verification checklist, known issues
- [Volume sync](docs/04-volume-sync.en.md) — theory, calibration, solved pitfalls

## ⚠️ Known limitations

- Volume sync uses SSH push; the slave must stay on the same LAN as the master (default home router works)
- If playback buffers for a long time (>seconds), the timeline re-aligns automatically and L/R may briefly desync
- Loudness curves differ slightly between models; tune the `CAL` factor in `vol_apply.sh`

## 🙏 Credits

- [open-xiaoai](https://github.com/idootop/open-xiaoai) — this project builds entirely on its stereo example and flashing methodology; the timeline-drift patch is an improvement to it

## License

MIT
