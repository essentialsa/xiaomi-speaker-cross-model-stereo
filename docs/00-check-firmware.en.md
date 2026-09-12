# 00 · Check the firmware versions

> Before flashing, check the current firmware version of both speakers in the Mi Home app —
> this determines which flashing path to take.

> 🌐 [简体中文](00-check-firmware.md) | [English](00-check-firmware.en.md)

---

## Steps

1. Open the **Mi Home** app
2. Select the speaker device, enter the detail page
3. Tap **「···」** (top right) → **General Settings** (or **About**)
4. Check **Firmware Version**

> 💡 If the version doesn't match the table below, that's fine —
> as long as the **model** matches (LX06 / OH2P), this project works.
> The version only affects whether OH2P needs a custom patched firmware.

## Version reference

| Device | Firmware used by this project | Note |
|---|---|---|
| XiaoAI Speaker Pro (LX06) | **1.94.13** | Official prebuilt patched firmware available, flash directly |
| Xiaomi Smart Speaker Pro (OH2P) | **1.62.2** | Build your own per [01-flash-oh2p.en.md](01-flash-oh2p.en.md) |

## Version → flashing path

```
Is your OH2P firmware version == 1.62.2 ?
├── Yes → use the prebuilt patched firmware (if a Release provides it)
└── No  → follow the "Build the patched firmware" section in 01-flash-oh2p.en.md,
          using your actual base version (same process, different source image)
```

> 💡 **Write down** both speakers' model and firmware version —
> the flashing docs will reference them.
