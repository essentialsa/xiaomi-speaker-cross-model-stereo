#!/bin/sh
# 主机音量处理
#   A) 音量联动：主机音量变化 → 写从机的目标文件
#   B) 主机静音补偿：校准 mysoftvol（音量 0 时主机真静音）
#
# 【防重复实例】PID 锁
LOCK=/tmp/vol_sync.lock
if [ -f "$LOCK" ]; then
  OLD=$(cat "$LOCK" 2>/dev/null)
  [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null && exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT INT TERM

SLAVE="<OH2P_IP>"   # ← 改成你的从机（OH2P）局域网 IP
KEY=/data/vol_id
FLOOR=25
SPAN=230
LAST=""
while true; do
  V=$(ubus call mediaplayer get_media_volume 2>/dev/null | grep -o "[0-9]*" | head -1)
  if [ -n "$V" ]; then
    # A) 联动推送（只在变化时推）
    if [ "$V" != "$LAST" ]; then
      if [ -n "$LAST" ]; then
        dbclient -i $KEY -y root@$SLAVE "echo $V > /data/vol_target" >/dev/null 2>&1
      fi
      LAST="$V"
    fi
    # B) 主机静音补偿
    WANT=$(( (V - FLOOR) * 255 / SPAN ))
    [ "$WANT" -lt 0 ] && WANT=0
    [ "$WANT" -gt 255 ] && WANT=255
    CUR=$(amixer sget mysoftvol 2>/dev/null | sed -n 's/^.*Front Left: \([0-9]*\).*/\1/p')
    if [ -n "$CUR" ] && [ "$CUR" != "$WANT" ]; then
      amixer sset mysoftvol $WANT >/dev/null 2>&1
    fi
  fi
  sleep 1
done
