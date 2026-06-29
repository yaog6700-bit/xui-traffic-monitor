#!/bin/bash
# xui-traffic-monitor 一键安装脚本
# 用法: bash <(curl -fsSL https://raw.githubusercontent.com/yaog6700-bit/xui-traffic-monitor/main/install.sh)
set -e

REPO="https://raw.githubusercontent.com/yaog6700-bit/xui-traffic-monitor/main"
SCRIPT_PATH="/root/xui_scan_all_cron.sh"
CONF="/etc/xui_scan.conf"
LOGFILE="/var/log/xui_scan.log"

echo "============================================"
echo "  3X-UI 流量巡检 一键安装"
echo "============================================"

# 0. 必须 root
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 请用 root 运行此脚本（sudo bash ...）"
  exit 1
fi

# 1. 安装依赖
echo "▶ 检查并安装依赖 (sqlite3 / curl)..."
if command -v apt >/dev/null 2>&1; then
  apt update -y >/dev/null 2>&1 || true
  apt install -y sqlite3 curl gawk grep coreutils >/dev/null 2>&1 || true
elif command -v yum >/dev/null 2>&1; then
  yum install -y sqlite curl gawk grep coreutils >/dev/null 2>&1 || true
fi
for c in sqlite3 curl awk grep; do
  command -v "$c" >/dev/null 2>&1 || { echo "❌ 依赖 $c 安装失败，请手动安装后重试"; exit 1; }
done
echo "  ✅ 依赖就绪"

# 2. 下载巡检脚本
echo "▶ 下载巡检脚本到 $SCRIPT_PATH ..."
curl -fsSL "$REPO/xui_scan_all_cron.sh" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
echo "  ✅ 下载完成"

# 3. 配置 Telegram
echo "▶ 配置 Telegram 推送（直接回车可跳过，仅本地打印）"
read -rp "  请输入 Telegram Bot Token: " TG_TOKEN
TG_CHAT=""
if [ -n "$TG_TOKEN" ]; then
  read -rp "  请输入 Telegram Chat ID: " TG_CHAT
fi
if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT" ]; then
  cat > "$CONF" <<EOF
TG_TOKEN="$TG_TOKEN"
TG_CHAT="$TG_CHAT"
EOF
  chmod 600 "$CONF"
  echo "  ✅ 已写入 $CONF（权限 600，仅 root 可读）"
else
  echo "  ⚠️ 未配置 Telegram，脚本将只在日志中打印报告"
fi

# 4. 添加 cron（每天 9:00），避免重复
echo "▶ 配置定时任务（每天 09:00 巡检）..."
CRON_LINE="0 9 * * * $SCRIPT_PATH >> $LOGFILE 2>&1"
( crontab -l 2>/dev/null | grep -v -F "$SCRIPT_PATH" ; echo "$CRON_LINE" ) | crontab -
echo "  ✅ 已添加 cron：$CRON_LINE"

# 5. 立即测试运行一次
echo "▶ 立即测试运行一次..."
echo "--------------------------------------------"
bash "$SCRIPT_PATH" || true
echo "--------------------------------------------"

echo ""
echo "🎉 安装完成！"
echo "  • 巡检脚本：$SCRIPT_PATH"
echo "  • 配置文件：$CONF"
echo "  • 日志文件：$LOGFILE"
echo "  • 定时任务：每天 09:00（用 crontab -l 查看）"
echo "  • 手动运行：bash $SCRIPT_PATH"
