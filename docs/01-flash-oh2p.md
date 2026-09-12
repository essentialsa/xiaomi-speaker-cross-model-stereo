# 01 · OH2P 刷机指南（小米智能音箱 Pro · Type-C 免拆机）
> 🌐 [简体中文](01-flash-oh2p.md) | [English](01-flash-oh2p.md)


> 目标：给 OH2P 刷入补丁固件，开启 SSH，获得对系统的完全控制。
> OH2P 支持 **Type-C 免拆机刷机**——只需一根能传数据的 Type-C 线。

## 0. 你需要准备

- OH2P 一台 + 能**传输数据**的 Type-C 线（⚠️ 纯充电线不行——插上电脑无任何反应就是线的问题）
- Mac/PC 一台（本指南以 macOS + Docker 为例）
- 小米账号（已绑定这台 OH2P），需要获取 `userId`、`passToken`、设备 `DID`
- [open-xiaoai](https://github.com/idootop/open-xiaoai) 仓库

## 1. 获取账号凭据

参照 open-xiaoai 的 [登录教程](https://github.com/idootop/open-xiaoai/blob/main/docs/mi-user.md)，
在仓库的 `packages/client-patch/.env` 中得到：

```
MI_USER=数字ID
MI_PASS=passToken
OH2P_DID=设备DID
```

## 2. 构建 OH2P 补丁固件

> 官方预编译固件仅覆盖 OH2P 的旧版本系统。如果你的 OH2P 是较新固件（如 1.62.2），
> 需要自制。以下命令在 Docker 中完成（需要 Docker Desktop 并启动）。

按官方 [client-patch 构建文档](https://github.com/idootop/open-xiaoai/blob/main/packages/client-patch/README.md) 执行，
构建环境为仓库的 Docker 交叉编译链（详见 [packages/runtime](https://github.com/idootop/open-xiaoai/tree/main/packages/runtime)）。

> 💡 构建完成后确认产物：`open-xiaoai/assets/` 下应有 `root-patched.squashfs`。
> 💡 拉取 Docker 镜像失败时：加 `--platform linux/amd64`（镜像仅 amd64 版本），
> 并使用镜像加速器前缀（如 `docker.1ms.run/`），拉取后 `docker tag` 改回原名。

> ⚠️ 构建镜像可能需要镜像加速器（Docker Hub 直连较慢）：
> 拉取失败时将镜像名前缀改为 `docker.1ms.run/` 再拉取。

## 3. 刷机

### 3.1 让 OH2P 进入刷机模式

1. 断开 OH2P 电源
2. 按住「播放/暂停」键不放
3. 插上 Type-C 线（连接电脑），保持按住约 6 秒后松开
4. 电脑上应出现新的 USB 设备（`WorldCup Device`）

> 💡 设备窗口期极短（0.2~1 秒）。建议使用仓库提供的连打探测脚本，
> 不间断地重试 `identify`，同时反复断电重试。

### 3.2 执行刷机

> 🔧 刷机工具下载：[Amlogic Flash Tool](https://androidmtk.com/download-amlogic-flash-tool)（Windows）
> macOS 用户使用 [open-xiaoai 自带的 flash 工具](https://github.com/idootop/open-xiaoai/tree/main/packages/flash-tool)。
> 连接问题排查：[官方排障帖](https://github.com/idootop/open-xiaoai/issues/6#issuecomment-2815632879)。

```bash
cd open-xiaoai
./flash.sh  # 按 1 选择 OH2P，按提示选择自制固件
```

刷机过程约 1-2 分钟。**全程不要断电。**

### 3.3 重启并验证

刷机完成后拔插电源，OH2P 重启：

```bash
ssh root@<OH2P_IP>
# 默认密码：open-xiaoai
```

## 4. 加固（强烈建议）

```bash
# 修改 root 密码（写入 /data，重启不丢）
passwd root

# 备份 mtd 分区（救砖用）
dd if=/dev/mtd0 of=/data/system0.bak
dd if=/dev/mtd1 of=/data/system1.bak
# 通过 scp 拷回电脑保存
```

## 5. 常见问题

| 现象 | 原因/解决 |
|---|---|
| 插上电脑无反应 | 线是纯充电线，换数据线 |
| identify 一直失败 | 刷机窗口太短，用连打脚本+反复断电 |
| 刷机后无法 SSH | 检查是否刷错分区；system0 是补丁系统，system1 是原厂 |
| 想恢复原厂 | 切回 boot1 分区即可（见 open-xiaoai 的 flash 工具） |
