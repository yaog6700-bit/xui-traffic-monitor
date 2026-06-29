#!/bin/bash
# xui-traffic-monitor 一键卸载脚本
# 用法: bash <(curl -fsSL https://raw.githubusercontent.com/yaog6700-bit/xui-traffic-monitor/main/uninstall.sh)

SCRIPT_PATH="/root/xui_scan_all_cron.sh"
SCRIPT_PATH2="/root/xui_scan_all.sh"
CONF="/etc/xui_scan.conf"
SNAP="/root/.xui_snap"
LOGFILE="/var/log/xui_scan.log"

echo "============================================"
echo "  3X-UI 流量巡检 一键卸载"
echo "============================================"

# 0. 必须 root
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 请用 root 运行此脚本（sudo bash ...）"
  exit 1
fi

# 1. 移除 cron 任务
echo "▶ 移除定时任务..."
if crontab -l 2>/dev/null | grep -qF "xui_scan_all"; then
  crontab -l 2>/dev/null | grep -v -F "xui_scan_all" | crontab -
  echo "  ✅ 已移除 cron 任务"
else
  echo "  ℹ️ 未发现相关 cron 任务"
fi

# 2. 删除脚本文件
echo "▶ 删除巡检脚本..."
for f in "$SCRIPT_PATH" "$SCRIPT_PATH2"; do
  [ -f "$f" ] && rm -f "$f" && echo "  ✅ 已删除 $f"
done

# 3. 删除快照
[ -f "$SNAP" ] && rm -f "$SNAP" && echo "  ✅ 已删除快照 $SNAP"

# 4. 询问是否删除配置文件（含 Token）
if [ -f "$CONF" ]; then
  read -rp "▶ 是否删除配置文件 $CONF（含 Telegram Token）？[y/N] " ans
  case "$ans" in
    [yY]*) rm -f "$CONF"; echo "  ✅ 已删除 $CONF" ;;
    *)     echo "  ⏭️ 保留 $CONF" ;;
  esac
fi

# 5. 询问是否删除日志
if [ -f "$LOGFILE" ]; then
  read -rp "▶ 是否删除日志文件 $LOGFILE？[y/N] " ans
  case "$ans" in
    [yY]*) rm -f "$LOGFILE"; echo "  ✅ 已删除 $LOGFILE" ;;
    *)     echo "  ⏭️ 保留 $LOGFILE" ;;
  esac
fi

echo ""
echo "🧹 卸载完成。"
