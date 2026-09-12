# 01 · OH2P Flashing Guide (Xiaomi Smart Speaker Pro · Type-C, no teardown)

> Goal: flash OH2P with patched firmware to enable SSH and gain full system control.
> OH2P supports **Type-C flashing without teardown** — you only need a Type-C cable that transfers data.

> 🌐 [简体中文](01-flash-oh2p.md) | [English](01-flash-oh2p.en.md)

---

## 0. Prerequisites

- OH2P + a Type-C cable that **transfers data** (⚠️ charge-only cables won't work — if the computer shows no reaction, it's the cable)
- Mac/PC (this guide uses macOS + Docker)
- A Xiaomi account bound to this OH2P, with `userId`, `passToken`, and the device `DID`
- The [open-xiaoai](https://github.com/idootop/open-xiaoai) repository

## 1. Get account credentials

Follow the open-xiaoai [login guide](https://github.com/idootop/open-xiaoai/blob/main/docs/mi-user.md) to obtain,
in `packages/client-patch/.env`:

```
MI_USER=numeric ID
MI_PASS=passToken
OH2P_DID=device DID
```

## 2. Build the OH2P patched firmware

> The official prebuilt firmware only covers older OH2P system versions.
> If yours is newer (e.g. 1.62.2), build your own. Docker Desktop must be running.

Follow the official [client-patch build docs](https://github.com/idootop/open-xiaoai/blob/main/packages/client-patch/README.md).
The build environment is the repo's Docker cross-compilation chain
(see [packages/runtime](https://github.com/idootop/open-xiaoai/tree/main/packages/runtime)).

> 💡 After building, verify the artifact: `open-xiaoai/assets/` should contain `root-patched.squashfs`.
> 💡 If pulling the Docker image fails: add `--platform linux/amd64` (the image is amd64-only),
> and use a registry mirror prefix (e.g. `docker.1ms.run/`), then `docker tag` it back to the original name.

## 3. Flash

### 3.1 Enter flash mode

1. Disconnect OH2P power
2. Hold the **Play/Pause** button
3. Plug in the Type-C cable (connected to the computer), keep holding ~6 seconds, release
4. The computer should detect a new USB device (`WorldCup Device`)

> 💡 The device window is extremely short (0.2–1 s). Use a continuous-probe loop
> that retries `identify` non-stop while power-cycling repeatedly.

### 3.2 Flash

> 🔧 Flash tool download: [Amlogic Flash Tool](https://androidmtk.com/download-amlogic-flash-tool) (Windows)
> macOS users: use [open-xiaoai's bundled flash tool](https://github.com/idootop/open-xiaoai/tree/main/packages/flash-tool).
> Connection troubleshooting: [official troubleshooting thread](https://github.com/idootop/open-xiaoai/issues/6#issuecomment-2815632879).

```bash
cd open-xiaoai
./flash.sh  # choose OH2P, then your custom firmware
```

Flashing takes 1–2 minutes. **Do not disconnect power.**

### 3.3 Reboot & verify

Disconnect and reconnect power:

```bash
ssh root@<OH2P_IP>
# default password: open-xiaoai
```

## 4. Hardening (strongly recommended)

```bash
passwd root          # change root password (persisted in /data)

# Backup mtd partitions (for recovery)
dd if=/dev/mtd0 of=/data/system0.bak
dd if=/dev/mtd1 of=/data/system1.bak
# scp them back to your computer
```

## 5. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No reaction when plugged in | Charge-only cable — use a data cable |
| identify keeps failing | Flash window too short — continuous-probe + power cycle |
| No SSH after flashing | Check partition; system0 = patched, system1 = stock |
| Restore stock | Switch back to the boot1 partition (see open-xiaoai flash tool) |
