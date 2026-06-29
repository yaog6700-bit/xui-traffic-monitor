# xui-traffic-monitor — 3X-UI 流量巡检脚本

用于 **3X-UI（x-ui）** 面板的流量巡检工具。它读取 x-ui 的数据库和访问日志，逐个入站端口统计上下行流量、识别是否在看视频站 / 下载站、判断是否多人共享 IP，把汇总报告打印到终端，并（可选）推送到 Telegram。

仓库内有 **两个脚本**，功能完全相同，只是「怎么提供 Telegram Token」的方式不同：

| 脚本 | 适用场景 | Token 提供方式 |
|------|----------|----------------|
| **`xui_scan_all.sh`** | 手动运行、临时查看 | 运行时**交互输入**（提示你敲 Token / ID） |
| **`xui_scan_all_cron.sh`** | 定时自动巡检（cron） | **非交互**：读环境变量或配置文件 |

> 简单记：**手动用 `xui_scan_all.sh`，定时用 `xui_scan_all_cron.sh`。**

---

## 🚀 一键安装（推荐）

在服务器上用 **root** 执行一条命令，自动完成：装依赖 → 下载脚本 → 配置 Telegram → 添加每天 09:00 的定时任务 → 立即测试运行。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yaog6700-bit/xui-traffic-monitor/main/install.sh)
```

安装过程中会提示你输入 Telegram Bot Token 和 Chat ID（直接回车可跳过，只本地打印不推送）。装完即生效，无需其他操作。

> 想手动安装、或了解两个脚本的区别，看下面的「方式一 / 方式二」。

---

## 🧹 一键卸载

移除 cron 任务、删除脚本和快照，并询问是否删除配置文件（含 Token）和日志：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yaog6700-bit/xui-traffic-monitor/main/uninstall.sh)
```

---

## 功能简介

对数据库里的每个入站端口，脚本会输出：

- 📊 **总上行 / 下行流量**，以及与上次巡检相比的「今日新增下行」(DELTA)
  - DELTA > 20 GB → 🔴 大流量下载
  - DELTA > 5 GB → 🟡 偏多
  - 其余 → 🟢 正常
- 👥 **连接的独立 IP 数**，用来判断账号是否被分享
  - ≤3 → ✅ 一人 ／ ≤6 → ⚠️ 可疑 ／ >6 → 🚨 多人共享
- 🎬 **访问的视频站**（YouTube、Netflix、TikTok、B 站、爱奇艺、Pornhub 等）
- 📥 **访问的下载站**（Steam、百度网盘、MEGA、Google Drive、迅雷等）
- 🔝 该端口访问最多的 5 个域名

报告先在终端以纯文本打印，然后（若配置了 Telegram）以 HTML 格式推送到指定聊天。

---

## 运行环境要求

- **系统**：Linux（已安装并运行 3X-UI 面板的服务器）
- **权限**：需要 **root** 运行（读取 `/etc/x-ui/` 数据库、写入 `/root/` 快照）
- **依赖**：`bash`、`sqlite3`、`curl`、`awk`、`grep`、`sed`

安装依赖：

```bash
# Debian / Ubuntu
apt update && apt install -y sqlite3 curl gawk grep coreutils
# CentOS / RHEL
yum install -y sqlite curl gawk grep coreutils
```

> 脚本依赖 x-ui 的「访问日志」。请在 3X-UI 面板的 **Xray 设置 / 日志** 里把 access log 路径设为 `/usr/local/x-ui/access.log` 并开启，否则视频站 / 下载站 / IP 识别会为空。

---

## 方式一：手动运行 —— `xui_scan_all.sh`（交互版）

适合临时看一眼、或测试 Telegram 通不通。

```bash
# 一行下载并加权限
curl -fsSL https://raw.githubusercontent.com/yaog6700-bit/xui-traffic-monitor/main/xui_scan_all.sh -o /root/xui_scan_all.sh && chmod +x /root/xui_scan_all.sh
# 运行
bash /root/xui_scan_all.sh
```

运行后会提示你输入：

```
请输入 Telegram Bot Token（直接回车跳过，仅本地显示）:
```

- **填入 Token** → 接着提示输入 Chat ID → 正常巡检并推送 Telegram。
- **直接回车跳过** → 只在终端打印报告，不推送。

> ⚠️ 交互版**不能**用于 cron。cron 没有键盘输入，`read` 会让任务卡住。

---

## 方式二：定时自动巡检 —— `xui_scan_all_cron.sh`（cron 版）

适合每天自动巡检并推送。Token 不写在脚本里，更安全。
（如果用了上面的「一键安装」，这一节可跳过——install.sh 已经帮你做完了。）

### 1. 下载脚本 + 加权限

```bash
curl -fsSL https://raw.githubusercontent.com/yaog6700-bit/xui-traffic-monitor/main/xui_scan_all_cron.sh -o /root/xui_scan_all_cron.sh && chmod +x /root/xui_scan_all_cron.sh
```

### 2. 建配置文件（推荐）

```bash
cat > /etc/xui_scan.conf <<'EOF'
TG_TOKEN="你的BotToken"
TG_CHAT="你的ChatID"
EOF
chmod 600 /etc/xui_scan.conf   # 只有 root 能读，防泄露
```

### 3. 加到 cron

```bash
crontab -e
```

加一行（每天早上 9:00 巡检并推送）：

```cron
0 9 * * * /root/xui_scan_all_cron.sh >> /var/log/xui_scan.log 2>&1
```

### Token 读取优先级

cron 版按以下顺序找 Token，找到即用：

1. **环境变量** `TG_TOKEN` / `TG_CHAT`（临时测试方便）
   ```bash
   TG_TOKEN="你的Token" TG_CHAT="你的ID" bash /root/xui_scan_all_cron.sh
   ```
2. **配置文件** `/etc/xui_scan.conf`（推荐 cron 用）
3. 都没有 → 只在日志打印，不推送

---

## 获取 Telegram Token 和 Chat ID

- **Bot Token**：在 Telegram 找 [@BotFather](https://t.me/BotFather)，发送 `/newbot` 创建机器人，它会给你一串 Token。
- **Chat ID**：先给你的机器人发一条消息，然后访问
  `https://api.telegram.org/bot<你的Token>/getUpdates`，在返回里找 `chat":{"id": ...}`。

---

## 输出示例（终端）

```
🛡️ 3X-UI 流量巡检  (2026-06-29 09:00)

🔌 443 [香港节点] user@example.com
  📊 ↑1.2G ↓35.4G (今日↓6.1G) 🟡偏多  配额100.0G
  👥 IP:2个 ✅一人
  🎬⚠️ 视频: googlevideo(120), nflxvideo(40)
  🔝 www.google.com(88), api.telegram.org(20)
```

---

## ⚠️ 安全注意事项

1. **不要把真实 Token 提交到公开 GitHub。** 仓库里的两个脚本默认 Token 为空，配置请放在 `/etc/xui_scan.conf`（不要上传该文件）。
2. 如果 Token 曾经泄露，请用 @BotFather 的 `/revoke` 重新生成。
3. 脚本会把数据库**临时复制**到 `/tmp/.xui_ro.db` 做只读查询，结束后删除，不修改原始数据库。

---

## 常见问题

**Q：提示「找不到数据库 /etc/x-ui/x-ui.db」**
用 `find / -name x-ui.db 2>/dev/null` 找到真实路径，改脚本里的 `DB` 变量。

**Q：视频站 / 下载站 / IP 都显示「无」或 0**
access log 没开或路径不对。检查 3X-UI 面板的 Xray 日志设置，确认 `/usr/local/x-ui/access.log` 存在且在记录。

**Q：`sqlite3: command not found`**
没装依赖，见上面「运行环境要求」。

**Q：Telegram 没收到消息**
检查 Token / Chat ID 是否正确，服务器能否访问 `api.telegram.org`（部分网络需要代理）。

**Q：「今日新增」不准**
脚本靠两次运行之间的快照算增量，建议**每天只跑一次**。第一次运行没有历史快照，增量从 0 算起。
