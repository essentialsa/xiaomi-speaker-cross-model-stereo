# 03 · Stereo Setup & Verification

> Prerequisite: both speakers are flashed, reachable via SSH, and on the same LAN.

> 🌐 [简体中文](03-stereo-setup.md) | [English](03-stereo-setup.en.md)

---

## 1. Static IPs (recommended)

In your router's admin UI, assign DHCP static leases,
e.g. LX06 = `192.168.31.12`, OH2P = `192.168.31.11`
(Xiaomi routers default to the 192.168.31.0/24 segment).

## 2. Configure master/slave roles

```bash
# Master (LX06, left channel + audio source)
ssh root@192.168.31.12 'mkdir -p /data/open-xiaoai && echo "master left" > /data/open-xiaoai/stereo.conf'

# Slave (OH2P, right channel)
ssh root@192.168.31.11 'mkdir -p /data/open-xiaoai && echo "slave right" > /data/open-xiaoai/stereo.conf'
```

Roles are swappable: for right-channel master, use `master right` + `slave left`.

## 3. Install the official stereo service

```bash
# On both devices
curl -sSfL https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/init.sh | sh

# Auto-start on boot
curl -L -o /data/init.sh https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/boot.sh
reboot
```

## 4. Apply this project's patches & scripts

### 4.1 Slave (OH2P) — three critical fixes

The stock configuration silently breaks stereo on OH2P. `scripts/init-slave.sh` handles:

1. **Audio chain bypass**: OH2P's `default` chain routes through Xiaomi's vis/safe_fifo layer,
   which blocks stereo writes. The script points `default` directly at the hardware mixer (`dsp`).
2. **Suppress mipns-xiaomi**: Xiaomi's audio service occupies the ALSA playback device,
   preventing stereo from opening it.
3. **Amp activation**: OH2P's audio amplifier needs one "activation" through the system audio path,
   otherwise stereo-written audio is silent. The script plays a very short chime.

```bash
scp scripts/init-slave.sh root@<OH2P_IP>:/data/init.sh
ssh root@<OH2P_IP> reboot
```

### 4.2 Master (LX06) — works out of the box

The master's stock configuration works as-is (ALSA redirection is built into stereo).

## 5. Verification checklist

```bash
# 1. Both stereo processes running
ssh root@192.168.31.12 'pidof stereo'    # master
ssh root@192.168.31.11 'pidof stereo'    # slave

# 2. Slave audio device open (should output 1)
ssh root@192.168.31.11 'ls -la /proc/$(pidof stereo)/fd/ | grep -c pcmC0D2p'

# 3. Master streaming (after playing music, ~1 packet per 20ms)
tcpdump -i any -n "udp and dst <slave IP>" -c 10
```

Play music — left/right channel separation means success.

## 6. Known issues & solutions

### Slave goes silent after pause/stutter during playback

This is the upstream stereo timeline-drift bug: playback time is computed from
"stream start + frame count"; playback stalls push the timeline behind the real clock,
and the slave drops all packets as "late".

**Fix**: apply the [timeline-drift patch](../patches/master-timeline-drift-fix.patch)
and recompile stereo (build instructions in [volume sync doc](04-volume-sync.en.md)).
The patch auto-realigns when the offset exceeds 200ms.

### Slave silent after reboot

When both devices power-cycle, the slave may come up before the master is ready.
Adjusting the slave's volume once in the app wakes the audio stack.
`scripts/init-slave.sh` automates this (plays a chime at startup).

### Master volume doesn't affect slave

Officially not supported. Use this project's [volume sync](04-volume-sync.en.md).
