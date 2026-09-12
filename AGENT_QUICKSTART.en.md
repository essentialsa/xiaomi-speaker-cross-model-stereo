# 🤖 Agent Quick Start · Automated Stereo Setup

> **This document is written for AI agents (Claude / GPT / Cursor, etc.).**
> Goal: configure two flashed XiaoAI speakers as a wireless stereo pair, automatically.
> Execute phase by phase: **after each phase, run the verification command. If the output doesn't match the expectation, stop and report to the user. Do not continue.**

> 🌐 [简体中文](AGENT_QUICKSTART.md) | [English](AGENT_QUICKSTART.en.md)

---

## Rules for the agent

1. **Execute in order.** Each phase ends with a verification command — actually run it and compare against the expected result.
2. **Do not skip steps.** Do not parallelize commands that modify the same device.
3. **All SSH commands** use the device addresses collected in "Phase 0". Do not guess.
4. On errors not covered by this document, collect the failing command, full output, and `/proc` state, then report to the user.
5. **Do not** test with high volume levels (disturbs the user). Use volume 40–90.

## Information needed from the user

Ask the user for the following before executing:

| Item | Example |
|---|---|
| Master (LX06) LAN IP | `192.168.31.12` |
| Slave (OH2P) LAN IP | `192.168.31.11` |
| Master SSH password | default `open-xiaoai` after flashing |
| Slave SSH password | set by the user during firmware build |

---

## Phase 0 · Connectivity & info gathering

```bash
ssh -o HostKeyAlgorithms=+ssh-rsa root@<LX06_IP> 'cat /proc/uptime'
ssh -o HostKeyAlgorithms=+ssh-rsa root@<OH2P_IP> 'cat /proc/uptime'
```

**Expected**: both output uptime numbers.
**On failure**: check network/password; confirm both devices are flashed.

```bash
ssh root@<OH2P_IP> 'sed -n "5p" /etc/asound.conf'
```

**Expected**: contains `pcm "vis"` (not yet bypassed → continue Phase 1)
or `pcm "dsp"` (already bypassed → skip step 1.1).

---

## Phase 1 · Slave audio chain fix

> Background: OH2P's `default` audio chain routes through Xiaomi's vis/safe_fifo layer,
> which blocks stereo writes. Bypass it and suppress the service occupying the device.

### 1.1 Apply bypass

```bash
ssh root@<OH2P_IP> 'grep -q "pcm \"dsp\"" /etc/asound.conf || {
  sed "s/pcm \"vis\"/pcm \"dsp\"/" /etc/asound.conf > /tmp/asound.stereo.conf
  mount --bind /tmp/asound.stereo.conf /etc/asound.conf
}'
```

### 1.2 Verify

```bash
ssh root@<OH2P_IP> 'sed -n "5p" /etc/asound.conf'
```

**Expected**: `pcm "dsp"`

---

## Phase 2 · Deploy stereo config

```bash
# Roles
ssh root@<LX06_IP> 'mkdir -p /data/open-xiaoai && echo "master left" > /data/open-xiaoai/stereo.conf'
ssh root@<OH2P_IP> 'mkdir -p /data/open-xiaoai && echo "slave right" > /data/open-xiaoai/stereo.conf'

# Official stereo service
ssh root@<LX06_IP> 'curl -sSfL https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/init.sh | sh'
ssh root@<OH2P_IP> 'curl -sSfL https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/init.sh | sh'

# Project scripts
scp scripts/init-slave.sh root@<OH2P_IP>:/data/init.sh
scp scripts/vol_apply.sh root@<OH2P_IP>:/data/vol_apply.sh
scp scripts/init-master.sh root@<LX06_IP>:/data/init.sh
scp scripts/vol_sync.sh root@<LX06_IP>:/data/vol_sync.sh

# Reboot both
ssh root@<LX06_IP> reboot && ssh root@<OH2P_IP> reboot
```

**Wait 2 minutes**, then verify.

---

## Phase 3 · Verification (all must pass)

### 3.1 Both stereo processes running

```bash
ssh root@<LX06_IP> 'pidof stereo'
ssh root@<OH2P_IP> 'pidof stereo'
```

**Expected**: one PID each.

### 3.2 Slave audio device open

```bash
ssh root@<OH2P_IP> 'ls -la /proc/$(pidof stereo)/fd/ | grep -c pcmC0D2p'
```

**Expected**: `1`
**On failure**: check if `/etc/asound.conf` is empty (stacked mounts wipe it):
`mount | grep -c asound` — if >1, umount all layers and redo Phase 1.

### 3.3 TCP connected

```bash
ssh root@<LX06_IP> 'netstat -tn | grep 53531'
```

**Expected**: one `ESTABLISHED` line.

### 3.4 Ask the user to play music in Mi Home and confirm OH2P outputs sound

**This must be confirmed by the user.** If silent, check in order:
1. Is `/etc/asound.conf` empty? (`wc -c /etc/asound.conf` — if 0, redo Phase 1)
2. Is the master streaming? On master: `tcpdump -i any -n -c 5 "udp and dst <OH2P_IP> and not dst port 53530"`
   - Packets → slave-side problem; no packets → master-side (is music actually playing?)

---

## Phase 4 · Volume sync deployment

### 4.1 SSH key auth (master → slave)

```bash
ssh root@<LX06_IP> 'dropbearkey -t rsa -s 2048 -f /data/vol_id'
ssh root@<LX06_IP> 'dropbearkey -y -f /data/vol_id | grep "^ssh-"'
```

Append the public key to the slave (⚠️ dropbear reads `/etc/dropbear/authorized_keys`, NOT `~/.ssh/`):

```bash
ssh root@<OH2P_IP> 'cp /etc/dropbear/authorized_keys /data/dropbear_authorized_keys 2>/dev/null; true'
ssh root@<OH2P_IP> 'echo "<master pubkey>" >> /data/dropbear_authorized_keys && chmod 600 /data/dropbear_authorized_keys'
ssh root@<OH2P_IP> 'mount --bind /data/dropbear_authorized_keys /etc/dropbear/authorized_keys'
```

### 4.2 Verify

```bash
ssh root@<LX06_IP> 'dbclient -i /data/vol_id -y root@<OH2P_IP> "echo KEY_OK"'
```

**Expected**: `KEY_OK`

### 4.3 Daemons auto-start via init scripts

---

## Phase 5 · Volume sync verification

> ⚠️ Use volume 40–60 for testing.

```bash
ssh root@<LX06_IP> 'ubus call mediaplayer player_set_volume "{\"volume\":40}"'
sleep 6
ssh root@<OH2P_IP> 'amixer sget Master | grep "Front Left:"'
```

**Expected**: Master ≈ 44%±5% (calibration maps internal [25..255] → Master [0..16]).

```bash
# Volume 0 → both truly silent
ssh root@<LX06_IP> 'ubus call mediaplayer player_set_volume "{\"volume\":0}"'
sleep 6
ssh root@<OH2P_IP> 'amixer sget Master | grep "Front Left:"'
```

**Expected**: `0%`
**On failure**: check `/data/vol_target` on the slave (was it written by the master?).

---

## Completion criteria

```
✅ Stereo configured
- LX06 (<IP>): master, left channel
- OH2P (<IP>): slave, right channel
- Volume sync: master drives slave; volume 0 = both silent
- Known limitation: loudness curves differ slightly between models (CAL factor in vol_apply.sh)
```

---

## Troubleshooting quick reference

| Symptom | Check first | Fix |
|---|---|---|
| Slave silent, ALSA device=0 | `/etc/asound.conf` empty? | Stacked mounts wipe it: umount all layers, redo Phase 1 |
| Slave silent, ALSA=1, receiving | Amp not activated | Play a short wav via `aplay -D default` |
| Master sends nothing | Slave list empty (handshake failed) | Restart master stereo (clears leaked sessions), wait for slave reconnect |
| Slave silent after volume change | Timeline drift | Confirm stereo binary contains the timeline patch |
| SSH push fails | Slave authorized_keys mount lost | Re-mount `/data/dropbear_authorized_keys` (Phase 4.1) |
