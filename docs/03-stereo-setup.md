# 03 · 立体声配置与验证
> 🌐 [简体中文](03-stereo-setup.md) | [English](03-stereo-setup.md)


> 前提：两台音箱已刷机并可通过 SSH 访问，且在同一局域网。

## 1. 固定 IP（推荐）

在路由器管理界面为两台音箱设置 DHCP 静态 IP 分配，
例如：LX06 = `192.168.31.12`、OH2P = `192.168.31.11`。

## 2. 配置主从角色

```bash
# 主机（LX06，左声道 + 音源）
ssh root@192.168.31.12 'mkdir -p /data/open-xiaoai && echo "master left" > /data/open-xiaoai/stereo.conf'

# 从机（OH2P，右声道）
ssh root@192.168.31.11 'mkdir -p /data/open-xiaoai && echo "slave right" > /data/open-xiaoai/stereo.conf'
```

角色可互换：想右声道走主机，改 `master right` + `slave left` 即可。

## 3. 安装官方立体声服务

```bash
# 两台都执行
curl -sSfL https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/init.sh | sh

# 开机自启
curl -L -o /data/init.sh https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/boot.sh
reboot
```

## 4. 应用本项目的补丁与脚本

### 4.1 从机（OH2P）—— 三项关键前置

从机的官方配置在 OH2P 上会静音，需要以下处理（已封装在 `scripts/init-slave.sh`）：

1. **音频链绕过**：OH2P 的 `default` 音频链经过小米的 vis/safe_fifo 分发层，
   stereo 写入会被堵住。脚本将 `default` 改为直连硬件混音器（`dsp`）。
2. **压制 mipns-xiaomi**：小米音频服务会占用 ALSA 播放设备，导致 stereo 打不开设备。
3. **功放激活**：OH2P 的音频功放需要被系统音频路径「激活」一次，
   否则 stereo 写入的音频静音。脚本播放一段极短的提示音来完成激活。

```bash
scp scripts/init-slave.sh root@<OH2P_IP>:/data/init.sh
ssh root@<OH2P_IP> reboot
```

### 4.2 主机（LX06）—— 无需额外处理

主机的官方配置开箱即用（音频链重定向由 stereo 自带）。

## 5. 验证清单

按顺序确认：

```bash
# 1. 两台 stereo 都在运行
ssh root@192.168.31.12 'pidof stereo'    # 主机
ssh root@192.168.31.11 'pidof stereo'    # 从机

# 2. 从机音频设备已打开（应输出 1）
ssh root@192.168.31.11 'ls -la /proc/$(pidof stereo)/fd/ | grep -c pcmC0D2p'

# 3. 主机已在发送音频（放歌后抓包，应每 20ms 一个包）
tcpdump -i any -n "udp and dst <从机IP>" -c 10
```

播放音乐，左右声道分离即成功。

## 6. 已知问题与解决

### 播放中暂停/卡顿后，从机静音

这是上游 stereo 的时间线漂移 Bug：播放时间基于「流起点+帧号」推算，
播放停顿会让时间线落后于真实时钟并累积，从机把所有音频包判定迟到而丢弃。

**修复**：应用 [时间线漂移补丁](../patches/master-timeline-drift-fix.patch)
并重新编译 stereo（见 [音量联动文档](04-volume-sync.md) 中的编译章节），
补丁会在时间线偏移超过 200ms 时自动重新对齐。

### 重启后从机静音

两台同时断电重启时，从机可能早于主机就绪。
在 App 里调一下从机音量即可触发唤醒。
`scripts/init-slave.sh` 已内置自动唤醒（启动时播放一段提示音）。

### 主机调音量，从机不跟随

官方不支持音量同步。使用本项目的 [音量联动](04-volume-sync.md) 功能解决。
