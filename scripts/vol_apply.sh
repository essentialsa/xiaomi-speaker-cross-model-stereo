#!/bin/sh
# 从机音量落地：把音量写到硬件混音器 Master（不碰 PCM 流，不会打断播放）
#
# 优先级：
#   1) 主机推来的目标（/data/vol_target）—— 主机音量变化时更新
#   2) 本机自己的音量（App/按键调节）—— 主机没变时生效
#
# 【防重复实例】PID 锁
LOCK=/tmp/vol_apply.lock
if [ -f "$LOCK" ]; then
  OLD=$(cat "$LOCK" 2>/dev/null)
  [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null && exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT INT TERM

# 【响度校准】两台音箱曲线不同：主机的 [25..255] → 从机 Master 的 [0..16]
# CAL = 校准系数百分比（100=1.0倍）。觉得从机偏响就调小，偏轻就调大。
CAL=100
FLOOR=25
SPAN=230
apply_master() {
  M=$(( ($1 - FLOOR) * 16 * CAL / SPAN / 100 ))
  [ "$M" -lt 0 ] && M=0
  [ "$M" -gt 16 ] && M=16
  amixer sset Master $M >/dev/null 2>&1
}
LAST_T=""
LAST_O=""
while true; do
  T=$(cat /data/vol_target 2>/dev/null | grep -o "[0-9]*" | head -1)
  O=$(ubus call mediaplayer get_media_volume 2>/dev/null | grep -o "[0-9]*" | head -1)
  if [ -n "$T" ] && [ "$T" != "$LAST_T" ]; then
    apply_master "$T"
    LAST_O="$O"
    LAST_T="$T"
  elif [ -n "$O" ] && [ "$O" != "$LAST_O" ]; then
    apply_master "$O"
    LAST_O="$O"
  fi
  sleep 2
done
