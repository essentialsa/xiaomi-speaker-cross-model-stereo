# 02 · LX06 Flashing Guide (XiaoAI Speaker Pro · Teardown + debug port)

> Goal: flash LX06 with patched firmware. LX06 requires teardown, connecting through
> the Micro USB debug port on the mainboard.
> LX06 has an officially prebuilt patched firmware (1.94.13) — **no need to build it yourself**.

> 🌐 [简体中文](02-flash-lx06.md) | [English](02-flash-lx06.en.md)

---

## 0. Prerequisites

- LX06
- **Micro-B USB data cable** (⚠️ must be the narrow USB 2.0 Micro-B — the wide Micro-B 3.0 used by portable drives won't fit)
- Phillips screwdriver, pry tool (for teardown)
- The [open-xiaoai](https://github.com/idootop/open-xiaoai) repository

## 1. Download the prebuilt patched firmware

LX06 has an official build — download directly:

```bash
# Patched firmware (flash to system0)
curl -LO https://github.com/idootop/open-xiaoai/releases/download/firmware/LX06_1.94.13_patched.squashfs
# Stock firmware (backup, for recovery)
curl -LO https://github.com/idootop/open-xiaoai/releases/download/firmware/LX06_1.94.13.squashfs

# Verify (SHA256 should match the official release)
shasum -a 256 LX06_1.94.13*.squashfs
```

## 2. Teardown

1. Bottom up, peel off the silicone base pad
2. Remove the hidden screws, take off the bottom cover
3. Disconnect the speaker cable from the mainboard
4. Remove the mainboard, flip to the back
5. Locate the **Micro USB debug port** on the mainboard

> 📷 **Teardown guide**: the official tutorial references a
> [full teardown article on 52audio](https://www.52audio.com/archives/38303.html);
> the debug port photo is in the
> [open-xiaoai official docs](https://github.com/idootop/open-xiaoai/blob/main/docs/images/mico-usb.jpg).
>
> ⚠️ The debug port is narrow Micro USB (USB 2.0). A wide Micro-B 3.0 (portable-drive type) won't fit.
>
> ⚠️ The flash window is extremely short (0.2–1 s). If the official `connect` command can't catch it, see
> the [official troubleshooting thread](https://github.com/idootop/open-xiaoai/issues/6#issuecomment-2815632879),
> or use this project's continuous-probe script (below).

## 3. Connect & enter flash mode

1. Reconnect the speaker cable, plug in power (the unit can boot)
2. Connect the Micro USB cable to the computer
3. A `WorldCup Device` appears on the computer = success

## 4. Flash

### ⚠️ Key technique: the flash window is only 0.2–1 second

Once the device enters flash mode, the bootloader window is extremely short.
**The official `connect` command (1-second sleep between retries) almost never catches it.**

Use a continuous-probe loop (the idea behind this repo's `catch-device.sh`):

```bash
while true; do ./identify && break; done
```

Combined with repeated power cycling. Measured hits: LX06 on attempt 1313, OH2P on 1000+.
**Once connected, the device stays online — subsequent commands don't need to race.**

After connecting:

```bash
./identify                     # confirm the device is online
./delay 15                     # stabilization delay
./switch boot0                 # switch to the flashable partition
./flash system0 LX06_1.94.13_patched.squashfs   # flash (1–2 minutes)
```

## 5. Reboot & verify

```bash
./switch boot1 && reboot       # or just power cycle
ssh root@<LX06_IP>
# default password: open-xiaoai
```

## 6. Hardening

```bash
passwd root                    # ⚠️ note: LX06 patched firmware /etc is read-only,
                               # the root password change may not persist — verify on your unit
dd if=/dev/mtd0 of=/data/system0.bak && dd if=/dev/mtd1 of=/data/system1.bak
```

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No reaction on the debug port | Charge-only cable / wide Micro-B — use a narrow data cable |
| identify fails | Window too short — continuous-probe + power cycle |
| No boot after reassembly | Check the speaker cable connection |
| SSH password isn't open-xiaoai | Confirm you flashed the patched firmware, not stock |
