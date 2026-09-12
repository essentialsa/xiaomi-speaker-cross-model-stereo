# 02 · LX06 刷机指南（小爱音箱 Pro · 拆机 + 调试口）
> 🌐 [简体中文](02-flash-lx06.md) | [English](02-flash-lx06.md)


> 目标：给 LX06 刷入补丁固件。LX06 需要拆机，通过主板上的 Micro USB 调试口连接。
> LX06 的补丁固件有官方现成版本（1.94.13），**无需自己构建**。

## 0. 你需要准备

- LX06 一台
- **Micro-B USB 数据线**（⚠️ 必须是 USB 2.0 的窄口 Micro-B，宽口的 Micro-B 3.0 插不进）
- 十字螺丝刀、撬片（拆机用）
- [open-xiaoai](https://github.com/idootop/open-xiaoai) 仓库

## 1. 下载现成补丁固件

LX06 的补丁固件有官方构建，直接下载：

```bash
# 补丁固件（刷入 system0）
curl -LO https://github.com/idootop/open-xiaoai/releases/download/firmware/LX06_1.94.13_patched.squashfs
# 原厂固件（备用，救砖）
curl -LO https://github.com/idootop/open-xiaoai/releases/download/firmware/LX06_1.94.13.squashfs

# 校验（SHA256 应与官方发布一致）
shasum -a 256 LX06_1.94.13*.squashfs
```

## 2. 拆机

1. 底部朝上，撕开底座硅胶垫
2. 拧下隐藏螺丝，取下底盖
3. 断开喇叭与主板的排线
4. 取出主板，翻到背面
5. 找到主板上的 **Micro USB 调试口**

> 📷 **拆机图解**：官方教程引用了 [52audio 的完整拆机文章](https://www.52audio.com/archives/38303.html)，
> 调试口位置图见 [open-xiaoai 官方文档](https://github.com/idootop/open-xiaoai/blob/main/docs/images/mico-usb.jpg)。
>
> ⚠️ 调试口是窄口 Micro USB（USB 2.0 规格）。手边只有移动硬盘那种宽口 Micro-B 的话是插不进去的。
>
> ⚠️ 刷机窗口极短（0.2~1 秒）。如果官方 `connect` 命令抓不到，参考
> [官方排障帖](https://github.com/idootop/open-xiaoai/issues/6#issuecomment-2815632879)，
> 或使用本项目的不间断连打探测脚本（见下方）。

## 3. 连接与进入刷机模式

1. 主板接上喇叭排线、插上电源（此时整机已可开机）
2. Micro USB 线连接电脑
3. 电脑上出现 `WorldCup Device` 即为成功

## 4. 刷机

### ⚠️ 关键技巧：刷机窗口只有 0.2~1 秒

设备进入刷机模式后，固件的引导窗口极短。**官方的 `connect` 命令（每轮 sleep 1 秒重试）几乎抓不到窗口。**

使用不间断连打探测（仓库 `catch-device.sh` 的思路）：

```bash
# 不间断循环执行 identify，直到命中
while true; do ./identify && break; done
```

配合反复断电重试。实测命中次数：LX06 第 1313 次、OH2P 第 1000+ 次。
**一旦命中，设备会稳定在线，后续操作不再需要抢时间。**

命中后依次执行：

```bash
./identify                     # 确认设备在线
./delay 15                     # 稳定延时
./switch boot0                 # 切换到可刷分区
./flash system0 LX06_1.94.13_patched.squashfs   # 刷入补丁固件（约 1-2 分钟）
```

## 5. 重启并验证

```bash
./switch boot1 && reboot       # 或直接断电重插
ssh root@<LX06_IP>
# 默认密码：open-xiaoai
```

## 6. 加固

```bash
passwd root                    # ⚠️ 注意：LX06 补丁固件的 /etc 是只读，
                               # root 密码修改在部分版本上不持久，请测试确认
dd if=/dev/mtd0 of=/data/system0.bak && dd if=/dev/mtd1 of=/data/system1.bak
```

## 7. 常见问题

| 现象 | 原因/解决 |
|---|---|
| 插上调试口无反应 | 线是充电线 / 口是宽口 Micro-B，换窄口数据线 |
| identify 失败 | 窗口短，用连打+断电重试 |
| 装回外壳后无法开机 | 检查喇叭排线是否插好 |
| SSH 密码不是 open-xiaoai | 确认刷的是 patched 固件而非原厂 |
