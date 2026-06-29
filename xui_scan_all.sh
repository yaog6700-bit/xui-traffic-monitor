#!/bin/bash
LOG="/usr/local/x-ui/access.log"
DB="/etc/x-ui/x-ui.db"
SNAP="/root/.xui_snap"
TG_TOKEN=""
TG_CHAT=""
# 交互式询问：若上面两项留空，则运行时提示输入（直接回车跳过，仅本地显示）
if [ -z "$TG_TOKEN" ]; then
  read -rp "请输入 Telegram Bot Token（直接回车跳过，仅本地显示）: " TG_TOKEN
fi
if [ -n "$TG_TOKEN" ] && [ -z "$TG_CHAT" ]; then
  read -rp "请输入 Telegram Chat ID: " TG_CHAT
fi
VIDEO='googlevideo|youtube|youtu\.be|ytimg|nflxvideo|netflix|ttvnw|twitch|tiktokcdn|tiktokv|bytevcdn|muscdn|douyin|douyincdn|bilivideo|bilibili|hdslb|iqiyi|qiyi|youku|disney|bamgrid|hbomax|max\.com|hulu|primevideo|amazonvideo|aiv-cdn|vimeo|dailymotion|phncdn|pornhub|xvideos|xnxx'
NOTVIDEO='accounts\.|login\.|auth\.|oauth|account\.|api\.|clients[0-9]'
DOWNLOAD='steamcontent|steampowered|steamcdn|steamstatic|pan\.baidu|baidupcs|pcs\.baidu|mega\.nz|mega\.io|mega\.co|mediafire|pikpak|drive\.google|drive\.usercontent|dropbox|onedrive|1drv|wetransfer|rapidgator|1fichier|uploaded\.|sourceforge|objects\.githubusercontent|aliyundrive|alipan|quark|123pan|thunder|xunlei'
fmt(){ awk -v b="$1" 'BEGIN{s="BKMGTP";i=1;while(b>=1024&&i<6){b/=1024;i++}printf "%.1f%s",b,substr(s,i,1)}'; }
[ ! -f "$DB" ] && echo "找不到数据库 $DB" && exit 1
TMPDB="/tmp/.xui_ro.db"
cp -f "$DB" "$TMPDB" 2>/dev/null
[ -f "$DB-wal" ] && cp -f "$DB-wal" "$TMPDB-wal" 2>/dev/null
[ -f "$DB-shm" ] && cp -f "$DB-shm" "$TMPDB-shm" 2>/dev/null
NOW=$(date '+%Y-%m-%d %H:%M')
MSG="🛡️ <b>3X-UI 流量巡检</b>  ($NOW)%0A"
declare -A PREV
[ -f "$SNAP" ] && while IFS='|' read -r p d; do PREV[$p]=$d; done < "$SNAP"
> "${SNAP}.tmp"
while IFS='|' read -r PORT REMARK EMAIL UP DOWN QUOTA; do
  [ -z "$PORT" ] && continue
  PD=${PREV[$PORT]:-$DOWN}
  DELTA=$((DOWN - PD)); [ "$DELTA" -lt 0 ] && DELTA=0
  echo "$PORT|$DOWN" >> "${SNAP}.tmp"
  if   [ "$DELTA" -gt $((20*1024*1024*1024)) ]; then TFLAG="🔴大流量下载!"
  elif [ "$DELTA" -gt $((5*1024*1024*1024)) ];  then TFLAG="🟡偏多"
  else TFLAG="🟢正常"; fi
  QS=""; [ "$QUOTA" -gt 0 ] && QS="  配额$(fmt $QUOTA)"
  L=$(grep -F "inbound-$PORT" "$LOG" 2>/dev/null)
  NIP=$(echo "$L" | grep -oE 'from [0-9.]+' | awk '{print $2}' | sort -u | grep -c .)
  if   [ "$NIP" -le 3 ]; then SHARE="✅一人"
  elif [ "$NIP" -le 6 ]; then SHARE="⚠️可疑"
  else SHARE="🚨多人共享"; fi
  DOMS=$(echo "$L" | grep -oE 'accepted [^ ]+' | awk '{print $2}' | sed -E 's#^(tcp|udp):##; s#:[0-9]+$##')
  VHITS=$(echo "$DOMS" | grep -ivE "$NOTVIDEO" | grep -iE "$VIDEO" | sort | uniq -c | sort -rn)
  VLIST=$(echo "$VHITS" | grep -v '^$' | head -4 | awk '{printf "%s%s(%s)", sep, $2, $1; sep=", "}')
  DHITS=$(echo "$DOMS" | grep -iE "$DOWNLOAD" | sort | uniq -c | sort -rn)
  DLIST=$(echo "$DHITS" | grep -v '^$' | head -4 | awk '{printf "%s%s(%s)", sep, $2, $1; sep=", "}')
  TOP=$(echo "$DOMS" | grep -vE '^[0-9.]+$' | sort | uniq -c | sort -rn | head -5 | awk '{printf "%s%s(%s)", sep, $2, $1; sep=", "}')
  MSG="$MSG%0A🔌 <b>$PORT</b> [$REMARK] $EMAIL%0A"
  MSG="$MSG  📊 ↑$(fmt $UP) ↓$(fmt $DOWN) (今日↓$(fmt $DELTA)) $TFLAG$QS%0A"
  MSG="$MSG  👥 IP:${NIP}个 $SHARE%0A"
  if [ -n "$VLIST" ]; then MSG="$MSG  🎬⚠️ 视频: $VLIST%0A"; else MSG="$MSG  🎬 视频站: 无%0A"; fi
  [ -n "$DLIST" ] && MSG="$MSG  📥⚠️ 下载站: $DLIST%0A"
  [ -n "$TOP" ] && MSG="$MSG  🔝 $TOP%0A"
done < <(sqlite3 "$TMPDB" "select i.port,i.remark,t.email,t.up,t.down,t.total from client_traffics t join inbounds i on t.inbound_id=i.id order by t.down desc")
mv "${SNAP}.tmp" "$SNAP"
rm -f "$TMPDB" "$TMPDB-wal" "$TMPDB-shm"
echo -e "$(echo "$MSG" | sed 's/%0A/\n/g; s/<[^>]*>//g')"
if [ -n "$TG_TOKEN" ]; then
  curl -s -o /dev/null "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" --data-urlencode "chat_id=${TG_CHAT}" --data-urlencode "parse_mode=HTML" --data "text=${MSG}"
  echo "(已发送 Telegram)"
else
  echo "(未配置 TG，仅本地显示)"
fi
