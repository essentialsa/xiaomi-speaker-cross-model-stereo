# 00 · 确认音箱固件版本
> 🌐 [简体中文](00-check-firmware.md) | [English](00-check-firmware.md)


> 开始刷机前，先在米家 App 里确认两台音箱的当前固件版本——
> 这决定了后续刷机方案的选择。

[简体中文](../README.md) | [English](../README.en.md)

---

## 步骤

1. 打开 **米家 App**
2. 找到对应的音箱设备，进入设备详情页
3. 点击右上角 **「···」** → **「通用设置」**（或「关于」）
4. 查看 **「固件版本」**（部分版本在「检查更新」页面）

> 💡 如果 App 里的版本号与下表对不上也没关系——
> 只要**型号匹配**（LX06 / OH2P），本项目就能用。
> 版本号只影响 OH2P 是否需要自制补丁固件。

## 版本对照表

| 设备 | 本项目使用的固件版本 | 说明 |
|---|---|---|
| 小爱音箱 Pro（LX06） | **1.94.13** | 官方已提供此版本的预编译补丁固件，直接下载刷入 |
| 小米智能音箱 Pro（OH2P） | **1.62.2** | 需按 [01-flash-oh2p.md](01-flash-oh2p.md) 自制补丁固件 |

## 版本与刷机方案的关系

```
你的 OH2P 固件版本 == 1.62.2 ？
├── 是 → 直接使用本项目预编译的补丁固件（若有 Release）
└── 否 → 按 01-flash-oh2p.md 的「构建补丁固件」章节，
        基于你的实际版本自行构建（构建流程相同，只是源固件不同）
```

> 💡 **记录下来**：把你两台音箱的型号和固件版本记下来，
> 后面的刷机文档会用到。

---

## English

## Step: Check the firmware versions

Before flashing, check the current firmware version of both speakers in the **Mi Home app**:

1. Open **Mi Home** → select the speaker → tap **「···」** (top right)
2. Go to **General Settings** (or **About**) → check **Firmware Version**

| Device | Firmware used by this project | Note |
|---|---|---|
| XiaoAI Speaker Pro (LX06) | **1.94.13** | Official prebuilt patched firmware available |
| Xiaomi Smart Speaker Pro (OH2P) | **1.62.2** | Custom firmware build required (see [01-flash-oh2p](01-flash-oh2p.md)) |

If your version differs, the project still works — you just need to
build the OH2P patched firmware from your own base image.
