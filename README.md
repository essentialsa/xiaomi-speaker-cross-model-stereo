# 小米音响跨型号立体声组网
> 🌐 [简体中文](README.md) | [English](README.en.md) | [🤖 Agent 快速开始](AGENT_QUICKSTART.md) | [🤖 Agent Quick Start](AGENT_QUICKSTART.en.md)


> 把两台不同型号的小爱音箱改造成一对真正的无线 Hi-Fi 立体声音箱。
> 左声道走主机，右声道走从机，代码级声道分离——不是两台机器放同一首歌。

![硬件](docs/images/hardware.jpg)

## ✨ 为什么值得试

| 亮点 | 说明 |
|---|---|
| 🎵 **真·立体声** | 在 ALSA 层截获系统音频，**代码逐采样点拆分左右声道**：左声道本地播放，右声道 Opus 编码后实时传给从机。不是"两台放同一首歌" |
| 🔀 **跨型号组网** | 小爱音箱 Pro（LX06）+ 小米智能音箱 Pro（OH2P），两个不同世代、不同固件的机型混搭 |
| 🛠 **修复上游时间线漂移 Bug** | 官方 stereo 的时间线基于「流起点+帧号」推算，播放中任何停顿都会累积漂移，从机把音频包全部判定迟到而静音。本项目的补丁让时间线自动对齐真实时钟，**暂停/续播/卡顿后自动恢复**（详见 [patches/](patches/)） |
| 🔊 **主从音量联动** | 官方明确「不支持同步音量」。本项目通过「主机推送 + 从机硬件混音器落地」实现主从响度同步，且音量 0 = 两台真静音 |
| 📦 **OH2P 新固件支持** | 官方预编译补丁固件仅覆盖旧版本，本项目提供 OH2P 1.62.2 自制补丁固件的完整构建方法 |
| 🚀 **断电即用** | 所有组件开机自启，断电重连后自动恢复立体声 |

## 📦 支持硬件

| 设备 | 型号 | 角色 | 刷机方式 |
|---|---|---|---|
| 小爱音箱 Pro | LX06 | 主节点（左声道 + 音源） | 拆机 + Micro USB（[指南](docs/02-flash-lx06.md)） |
| 小米智能音箱 Pro | OH2P | 从节点（右声道） | Type-C 免拆机（[指南](docs/01-flash-oh2p.md)） |

## 🏗 工作原理

```
                    ┌─────────────────────────────────┐
   米家 App / 蓝牙   │  LX06（主节点 · 左声道）          │
        │           │                                 │
        ▼           │  mediaplayer                    │
   小米音乐服务       │      │ ALSA 重定向              │
        │           │      ▼                         │
        └──────────▶│  /tmp/stereo_out.fifo          │
                    │      │                         │
                    │      ▼                         │
                    │  stereo（主机）                  │
                    │   ├─ 拆分声道：L → 本地播放       │
                    │   └─ R → Opus 编码              │
                    │           │ UDP :53531          │
                    └───────────┼─────────────────────┘
                                │ 局域网
                                ▼
                    ┌─────────────────────────────────┐
                    │  OH2P（从节点 · 右声道）          │
                    │                                 │
                    │  stereo（从机）                  │
                    │   ├─ 接收 → 解码 → 播放 R        │
                    │   └─ 时钟同步（NTP+Kalman）      │
                    │                                 │
                    │  vol_apply 守护                  │
                    │   └─ 音量 → 硬件混音器 Master     │
                    └─────────────────────────────────┘
```

**音量联动**：主机检测到音量变化后，把目标值推送给从机；从机守护进程将音量写入硬件混音器（绕开会缓存音量、干扰播放的 ALSA softvol）。音量信息与播放流分离，互不干扰。

## 🚀 快速开始

> 前提：两台音箱已刷入补丁固件并获得 SSH 访问。
> 刷机请按顺序阅读：[OH2P 刷机](docs/01-flash-oh2p.md) → [LX06 刷机](docs/02-flash-lx06.md)

### 1. 配置主从角色

```bash
# 主机（LX06）
ssh root@<LX06_IP> 'mkdir -p /data/open-xiaoai && echo "master left" > /data/open-xiaoai/stereo.conf'

# 从机（OH2P）
ssh root@<OH2P_IP> 'mkdir -p /data/open-xiaoai && echo "slave right" > /data/open-xiaoai/stereo.conf'
```

### 2. 安装立体声服务

```bash
# 两台都执行（官方 init 脚本）
curl -sSfL https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/init.sh | sh
```

### 3. 应用本项目补丁与脚本

```bash
# 从机（OH2P）—— 应用音频链绕过 + 功放激活 + 音量落地守护
scp scripts/init-slave.sh root@<OH2P_IP>:/data/init.sh

# 主机（LX06）—— 应用音量联动守护
scp scripts/init-master.sh root@<LX06_IP>:/data/init.sh
scp scripts/vol_sync.sh root@<LX06_IP>:/data/vol_sync.sh
scp scripts/vol_apply.sh root@<OH2P_IP>:/data/vol_apply.sh

# 两台重启
ssh root@<LX06_IP> reboot && ssh root@<OH2P_IP> reboot
```

### 4. 享受立体声

在米家 App / 蓝牙 / 小爱同学播放任意音频——左右声道自动分离。

## 📁 项目结构

```
├── README.md
├── docs/
│   ├── 01-flash-oh2p.md        # OH2P 刷机（Type-C 免拆机 + 自制固件）
│   ├── 02-flash-lx06.md        # LX06 刷机（拆机 + 调试口）
│   ├── 03-stereo-setup.md      # 立体声配置与验证
│   └── 04-volume-sync.md       # 音量联动原理与安装
├── patches/
│   └── master-timeline-drift-fix.patch   # 上游时间线漂移修复
├── scripts/
│   ├── init-master.sh          # 主机开机脚本（含音量联动守护）
│   ├── init-slave.sh           # 从机开机脚本（音频链绕过 + 功放激活 + 音量落地）
│   ├── vol_sync.sh             # 主机音量推送守护
│   └── vol_apply.sh            # 从机音量落地守护
└── firmware/                   # （空目录）固件请自行构建或从 Release 下载
```

## 📖 详细文档

- [OH2P 刷机指南](docs/01-flash-oh2p.md) — 含 1.62.2 自制补丁固件构建
- [LX06 刷机指南](docs/02-flash-lx06.md) — 拆机图解、刷机窗口技巧
- [立体声配置](docs/03-stereo-setup.md) — 角色配置、验证清单、常见问题
- [音量联动](docs/04-volume-sync.md) — 原理、校准、已解决的坑

## ⚠️ 已知限制

- 音量联动基于 SSH 推送，从机需保持与主机同网段（家庭路由器默认满足）
- 播放中如果出现长时间缓冲（>数秒），时间线会自动重新对齐，左右声道可能有短暂偏差
- 不同型号的响度曲线略有差异，可用 `vol_apply.sh` 中的 `CAL` 系数微调

## 🙏 致谢

- [open-xiaoai](https://github.com/idootop/open-xiaoai) — 本项目全部基于此项目的 stereo 示例与刷机方案，时间线漂移补丁也是对其的改进
- [小爱音箱吧](https://tieba.baidu.com/f?kw=小爱音箱) 社区的刷机探索

## License

MIT
