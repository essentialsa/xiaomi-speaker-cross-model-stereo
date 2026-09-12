# 🤖 Agent 快速开始 · 立体声自动配置

> **本文档供 AI Agent（Claude / GPT / Cursor 等）执行。**
> 目标：把两台已刷入补丁固件的小爱音箱自动配置为一对无线立体声。
> 请逐阶段执行：**每个阶段结束后运行验证命令，输出与「期望结果」不符时立即停止并向用户报告，不要继续。**

> 🌐 [简体中文](AGENT_QUICKSTART.md) | [English](AGENT_QUICKSTART.en.md)

---

## 给 Agent 的执行规则

1. **顺序执行**，每个阶段末尾有验证命令，必须实际运行并比对输出
2. **不要跳步**，不要并行执行会修改同一设备的命令
3. **所有 SSH 命令**的设备地址来自「阶段 0」收集的信息，不要猜测
4. 遇到本文档未覆盖的错误时，收集以下信息后向用户报告：出错的命令、完整输出、`/proc` 状态
5. **禁止**使用大音量测试（会吵到用户），测试音量用 40~90

## 需要用户提供的信息

向用户询问以下内容（缺失时先问再执行）：

| 信息 | 示例 |
|---|---|
| 主机（LX06）的局域网 IP | `192.168.31.12` |
| 从机（OH2P）的局域网 IP | `192.168.31.11` |
| 主机 SSH 密码 | 刷机后默认 `open-xiaoai` |
| 从机 SSH 密码 | 刷机时用户设置（见其固件构建记录） |

将以上信息写入本地环境（后续所有命令引用）。

---

## 阶段 0 · 连通性与信息收集

```bash
# 验证两台可达（应各自返回一串数字 uptime）
ssh -o HostKeyAlgorithms=+ssh-rsa root@<LX06_IP> 'cat /proc/uptime'
ssh -o HostKeyAlgorithms=+ssh-rsa root@<OH2P_IP> 'cat /proc/uptime'
```

**期望结果**：两条命令都输出 uptime 数字。
**失败处理**：检查网络/密码；确认两台都已刷机。

```bash
# 收集从机的音频链信息（后续验证需要）
ssh root@<OH2P_IP> 'sed -n "5p" /etc/asound.conf'
```

**期望结果**：输出包含 `pcm "vis"` 或 `pcm "dsp"`。
- 如果是 `vis` → 从机尚未应用本项目的绕过配置，**继续执行阶段 1**
- 如果是 `dsp` → 已应用过，**跳过阶段 1 的第 1 步**

---

## 阶段 1 · 从机音频链修复

> 背景：OH2P 的 `default` 音频链经过小米的 vis/safe_fifo 分发层，
> stereo 写入会被堵住导致静音。需绕过它，并压制占用设备的小米服务。

### 1.1 备份并应用音频链绕过

```bash
ssh root@<OH2P_IP> 'grep -q "pcm \"dsp\"" /etc/asound.conf || {
  sed "s/pcm \"vis\"/pcm \"dsp\"/" /etc/asound.conf > /tmp/asound.stereo.conf
  mount --bind /tmp/asound.stereo.conf /etc/asound.conf
}'
```

### 1.2 验证

```bash
ssh root@<OH2P_IP> 'sed -n "5p" /etc/asound.conf'
```

**期望结果**：`pcm "dsp"`
**失败处理**：检查 /etc/asound.conf 是否被其他挂载覆盖（`mount | grep asound`）。

---

## 阶段 2 · 部署立体声配置

### 2.1 写入主从角色

```bash
ssh root@<LX06_IP> 'mkdir -p /data/open-xiaoai && echo "master left" > /data/open-xiaoai/stereo.conf'
ssh root@<OH2P_IP> 'mkdir -p /data/open-xiaoai && echo "slave right" > /data/open-xiaoai/stereo.conf'
```

### 2.2 安装官方立体声服务

```bash
ssh root@<LX06_IP> 'curl -sSfL https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/init.sh | sh'
ssh root@<OH2P_IP> 'curl -sSfL https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/init.sh | sh'
```

### 2.3 部署本项目脚本

将本仓库 `scripts/` 目录的内容上传：
- `init-slave.sh` → 从机 `/data/init.sh`
- `vol_apply.sh` → 从机 `/data/vol_apply.sh`
- `init-master.sh` → 主机 `/data/init.sh`
- `vol_sync.sh` → 主机 `/data/vol_sync.sh`

```bash
scp scripts/init-slave.sh root@<OH2P_IP>:/data/init.sh
scp scripts/vol_apply.sh root@<OH2P_IP>:/data/vol_apply.sh
scp scripts/init-master.sh root@<LX06_IP>:/data/init.sh
scp scripts/vol_sync.sh root@<LX06_IP>:/data/vol_sync.sh
```

### 2.4 重启两端

```bash
ssh root@<LX06_IP> reboot
ssh root@<OH2P_IP> reboot
```

**等待 2 分钟后**进入验证。

---

## 阶段 3 · 验证（必须全部通过）

### 3.1 两台 stereo 运行

```bash
ssh root@<LX06_IP> 'pidof stereo'
ssh root@<OH2P_IP> 'pidof stereo'
```

**期望结果**：各输出一个 PID。

### 3.2 从机音频设备已打开

```bash
ssh root@<OH2P_IP> 'ls -la /proc/$(pidof stereo)/fd/ | grep -c pcmC0D2p'
```

**期望结果**：`1`
**失败处理**：检查 `/etc/asound.conf` 是否为空（被重复挂载清空）：
`mount | grep -c asound`，若 >1 则需要 `umount` 多层后重新配置。

### 3.3 TCP 已连接

```bash
ssh root@<LX06_IP> 'netstat -tn | grep 53531'
```

**期望结果**：一行 `ESTABLISHED`。
**失败处理**：等待 60 秒再查（从机重连需要时间）；仍失败则重启从机 stereo。

### 3.4 让用户在米家 App 播放音乐，确认 OH2P 出声

**这一步必须由用户人工确认**。无声时按顺序检查：
1. 从机 `/etc/asound.conf` 是否为空文件（`wc -c /etc/asound.conf`，为 0 则按阶段 1 修复）
2. 主机是否在发音频：主机上 `tcpdump -i any -n -c 5 "udp and dst <OH2P_IP> and not dst port 53530"`
   - 有包 → 从机侧问题；无包 → 主机侧问题（音乐是否真的在播）

---

## 阶段 4 · 音量联动部署

### 4.1 建立 SSH 免密（主机 → 从机）

```bash
# 主机生成密钥
ssh root@<LX06_IP> 'dropbearkey -t rsa -s 2048 -f /data/vol_id'
# 取公钥（输出以 ssh-rsa 开头的一行）
ssh root@<LX06_IP> 'dropbearkey -y -f /data/vol_id | grep "^ssh-"'
```

将公钥追加到从机（注意：dropbear 从 `/etc/dropbear/authorized_keys` 读取，不是 `~/.ssh/`）：

```bash
ssh root@<OH2P_IP> 'cp /etc/dropbear/authorized_keys /data/dropbear_authorized_keys 2>/dev/null; true'
ssh root@<OH2P_IP> 'echo "<主机公钥>" >> /data/dropbear_authorized_keys && chmod 600 /data/dropbear_authorized_keys'
ssh root@<OH2P_IP> 'mount --bind /data/dropbear_authorized_keys /etc/dropbear/authorized_keys'
```

### 4.2 验证免密

```bash
ssh root@<LX06_IP> 'dbclient -i /data/vol_id -y root@<OH2P_IP> "echo KEY_OK"'
```

**期望结果**：`KEY_OK`
**失败处理**：确认从机 `/etc/dropbear/authorized_keys` 包含公钥（`wc -l` ≥ 2 表示原有密钥+新增）。

### 4.3 守护进程已在开机脚本中，重启后自动运行

`init-master.sh` 会启动 `vol_sync.sh`（推送），`init-slave.sh` 会启动 `vol_apply.sh`（落地）。

---

## 阶段 5 · 音量联动验证

> ⚠️ 用中等音量测试（App 音量条 40~60），不要用大音量。

```bash
# 设主机音量 40 → 从机硬件 Master 应变为约 44%
ssh root@<LX06_IP> 'ubus call mediaplayer player_set_volume "{\"volume\":40}"'
sleep 6
ssh root@<OH2P_IP> 'amixer sget Master | grep "Front Left:"'
```

**期望结果**：Master 约 44%±5%（校准映射：internal [25..255] → Master [0..16]）。

```bash
# 主机音量 0 → 从机 Master 应为 0%（真静音）
ssh root@<LX06_IP> 'ubus call mediaplayer player_set_volume "{\"volume\":0}"'
sleep 6
ssh root@<OH2P_IP> 'amixer sget Master | grep "Front Left:"'
```

**期望结果**：`0%`
**失败处理**：检查从机 `/data/vol_target` 是否被主机写入（`cat /data/vol_target`）；
为空说明主机推送失败 → 检查 4.2 的免密是否仍生效。

---

## 完成标准

全部通过后，向用户报告：

```
✅ 立体声配置完成
- LX06（<IP>）：主节点，左声道
- OH2P（<IP>）：从节点，右声道
- 音量联动：主机调节时从机同步，音量 0 双机静音
- 已知限制：不同型号响度曲线略有差异，可调 vol_apply.sh 中 CAL 系数
- 从机音量也可在 App 中单独调节（不影响主机）
```

---

## 故障速查表

| 症状 | 首选检查 | 修复 |
|---|---|---|
| 从机无声、ALSA 设备=0 | `/etc/asound.conf` 是否为空 | 重复挂载会清空文件：umount 全部层后按阶段 1 重做 |
| 从机无声、ALSA 设备=1、收包正常 | 功放未激活 | `aplay -D default <短音wav>` 播一段后重试 |
| 主机不发包 | 从机列表为空（握手失败） | 重启主机 stereo（清泄漏会话）后再等从机重连 |
| 调音量后从机静音 | 时间线漂移 | 确认 stereo 二进制含时间线补丁（md5 对比仓库 patches 说明） |
| SSH 推送失败 | 从机 authorized_keys 挂载丢失 | 重挂 `/data/dropbear_authorized_keys`（见阶段 4.1） |
