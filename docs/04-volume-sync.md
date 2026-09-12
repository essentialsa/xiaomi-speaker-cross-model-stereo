# 04 · 音量联动：主从响度同步
> 🌐 [简体中文](04-volume-sync.md) | [English](04-volume-sync.md)


> 官方 stereo 明确「不支持同步音量大小」。本文档提供一套完整的解决方案。

## 1. 为什么难

| 难点 | 原因 |
|---|---|
| 音频流里没有音量信息 | 主机把音频编码后原样发送，不携带音量元数据 |
| 两台型号曲线不同 | 同一数值对应的物理响度不同（实测两台的接口地板值也不同） |
| ALSA softvol 会缓存 | softvol 打开 PCM 时锁定音量，改控件不跟随且会干扰播放流 |
| 接口单位不对称 | `get` 返回 0-255，`set` 参数是 0-100（音量条值） |

## 2. 设计

```
主机（LX06）                         从机（OH2P）
┌──────────────────┐                ┌──────────────────────┐
│ vol_sync 守护     │    SSH（密钥）  │ vol_apply 守护        │
│ 监听主机音量       │ ──目标值──────▶ │ 读目标 → 硬件混音器    │
│ （只在变化时推送）  │                │ Master 写入硬件寄存器  │
└──────────────────┘                └──────────────────────┘
```

**关键决策：**

1. **音量作用点 = 硬件混音器 `Master`**（0-16）
   ALSA 的 softvol 在打开 PCM 时缓存音量值，之后改控件既不跟随还会干扰播放流。
   硬件寄存器实时生效且完全不触碰 PCM 流。

2. **地板值对齐**：两台的音量接口都有地板值（设 0 时 internal 仍为 25），
   但 internal=25 时主机=静音、从机=仍有小声。
   映射时将对齐为：`主机的 [25..255] → 从机 Master 的 [0..16]`，
   保证音量 0 时两台同时真静音。

3. **只在变化时推送**：从机单独调节不会被主机覆盖。

## 3. 安装

### 3.1 建立主机→从机的 SSH 免密

两台设备的 dropbear 从 `/etc/dropbear/authorized_keys` 读取授权密钥
（全局路径，不是 `~/.ssh/`），而 `/etc` 是只读的，所以用 bind-mount：

```bash
# 主机生成密钥
ssh root@<LX06_IP> 'dropbearkey -t rsa -s 2048 -f /data/vol_id'
# 取公钥
ssh root@<LX06_IP> 'dropbearkey -y -f /data/vol_id | grep "^ssh-"'
```

```bash
# 从机：备份原文件 → 追加主机公钥 → bind-mount
ssh root@<OH2P_IP> 'cp /etc/dropbear/authorized_keys /data/dropbear_authorized_keys'
ssh root@<OH2P_IP> 'echo "<主机公钥>" >> /data/dropbear_authorized_keys'
ssh root@<OH2P_IP> 'chmod 600 /data/dropbear_authorized_keys'
ssh root@<OH2P_IP> 'mount --bind /data/dropbear_authorized_keys /etc/dropbear/authorized_keys'
```

> ⚠️ dropbear 2017.75 只支持 RSA/DSS 密钥（不支持 ed25519）。
> ⚠️ bind-mount 不持久，必须写入从机的开机脚本（`init-slave.sh` 已包含）。

### 3.2 部署守护

```bash
scp scripts/vol_sync.sh  root@<LX06_IP>:/data/vol_sync.sh
scp scripts/vol_apply.sh root@<OH2P_IP>:/data/vol_apply.sh

# 加入开机脚本（两个 init-*.sh 已内置）
```

## 4. 响度校准

两台音箱型号不同，响度曲线有差异。`vol_apply.sh` 提供 `CAL` 校准系数：

```bash
CAL=100    # 100 = 1.0 倍。从机偏响调小（如 90），偏轻调大（如 110）
```

**校准方法**：两边播放同一首歌，调节主节点音量到中间位置，
听两边响度是否一致，不一致就调 CAL（每次改完需重启从机 stereo 并切一次歌）。

## 5. 编译带时间线修复的 stereo

音量联动的前提是立体声连接稳定，而上游 stereo 有时间线漂移 Bug。
需要应用补丁并重新编译：

```bash
# 应用补丁
cd open-xiaoai
git apply patches/master-timeline-drift-fix.patch

# 编译（需要 Docker Desktop 运行）
cd examples/stereo && make build
# 产物：target/armv7-unknown-linux-gnueabihf/release/stereo
```

> 💡 macOS Apple Silicon 上拉取镜像需指定平台：
> `docker pull --platform linux/amd64 <镜像名>`
> Docker Hub 直连失败时使用镜像加速器（如 `docker.1ms.run/` 前缀）。

部署到两台设备后重启即可。
