#!/bin/sh
# open-xiaoai stereo 从机前置
# 1) default 指向 dsp：绕过 vis 链（仅当尚未绕过时才挂载，避免叠加）
if ! grep -q "pcm \"dsp\"" /etc/asound.conf 2>/dev/null; then
  sed "s/pcm \"vis\"/pcm \"dsp\"/" /etc/asound.conf > /tmp/asound.stereo.conf
  mount --bind /tmp/asound.stereo.conf /etc/asound.conf
fi
# 2) 压制 mipns-xiaomi
( i=0; while [ $i -lt 60 ]; do kill -9 $(pidof mipns-xiaomi) 2>/dev/null; sleep 1; i=$((i+1)); done ) &
sleep 1
# 3) 激活功放
# 5) 音量落地守护
( sh /data/vol_apply.sh >/dev/null 2>&1 & )
# 6) SSH 免密挂载（音量联动需要）
if [ -f /data/dropbear_authorized_keys ]; then mount --bind /data/dropbear_authorized_keys /etc/dropbear/authorized_keys 2>/dev/null; fi
aplay -D default /usr/share/sound-vendor/AiNiRobot/wakeup_zai_01.wav >/dev/null 2>&1
sleep 1
# open-xiaoai stereo: mipns-xiaomi 占用 ALSA 播放设备会导致从机无声，
# 且它有守护会持续复活。必须永久压制（每5秒清一次），否则立体声失效。
# 原始 boot.sh 备份: /data/init.sh.orig
( while true; do kill -9 $(pidof mipns-xiaomi) 2>/dev/null; sleep 5; done ) &
sleep 1
# open-xiaoai stereo: mipns-xiaomi 会占用 ALSA 播放设备，必须先清掉
kill -9 $(pidof mipns-xiaomi) 2>/dev/null
sleep 1

exec > /dev/null 2>&1

WORK_DIR="/data/open-xiaoai"
APP_BINARY="$WORK_DIR/stereo"
CONFIG_FILE="$WORK_DIR/stereo.conf"
DOWNLOAD_URL="https://gitee.com/idootop/artifacts/releases/download/open-xiaoai-stereo/stereo"

cat << 'EOF'

▄▖      ▖▖▘    ▄▖▄▖
▌▌▛▌█▌▛▌▚▘▌▀▌▛▌▌▌▐ 
▙▌▙▌▙▖▌▌▌▌▌█▌▙▌▛▌▟▖
  ▌ - Stereo（立体声）          

v1.0.0  by: https://del.wang

EOF

# 等待能够正常访问 baidu.com
while ! ping -c 1 baidu.com > /dev/null 2>&1; do
    echo "🤫 等待网络连接中..."
    sleep 1
done

sleep 3

echo "✅ 网络连接成功"

main() {
    # 1. 确保目录存在
    [ -d "$WORK_DIR" ] || mkdir -p "$WORK_DIR"

    # 2. 检查并下载程序
    if [ ! -f "$APP_BINARY" ]; then
        echo "🚀 正在下载 Stereo 立体声程序..."
        if ! curl -L -# -f -o "$APP_BINARY" "$DOWNLOAD_URL"; then
            echo "❌ 下载失败，请检查网络连接。"
            exit 1
        fi
        chmod +x "$APP_BINARY"
        echo "✅ 程序下载完毕"
    fi

    # 3. 如果运行脚本时带了参数，则覆盖更新配置文件
    if [ $# -gt 0 ]; then
        echo "$*" > "$CONFIG_FILE"
    fi

    # 4. 读取配置
    local ARGS=""
    if [ -f "$CONFIG_FILE" ]; then
        ARGS=$(cat "$CONFIG_FILE")
    fi

    # 5. 停止旧进程
    PID=$(pgrep -f "$APP_BINARY" || true)
    if [ -n "$PID" ]; then
        kill -9 $PID > /dev/null 2>&1 || true
    fi

    # 6. 启动程序
    echo "🔥 Stereo 立体声程序启动中..."
    "$APP_BINARY" $ARGS
}

main "$@"