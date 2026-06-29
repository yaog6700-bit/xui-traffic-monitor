# xui_scan_all.sh — 3X-UI 流量巡检脚本

一个用于 **3X-UI（x-ui）** 面板的流量巡检脚本。它会读取 x-ui 的数据库和访问日志，逐个入站端口统计上下行流量、识别是否在看视频站 / 下载站、判断是否存在多人共享 IP，并把一份汇总报告打印到终端，同时（可选）推送到 Telegram。

---

## 功能简介

对数据库里的每个入站端口，脚本会输出：

- 📊 **总上行 / 下行流量**，以及与上次巡检相比的「今日新增下行」(DELTA)
  - DELTA > 20 GB → 🔴 大流量下载
  - DELTA > 5 GB → 🟡 偏多
  - 其余 → 🟢 正常
- 👥 **连接的独立 IP 数**，用来判断账号是否被分享
  - ≤3 个 IP → ✅ 一人
  - ≤6 个 IP → ⚠️ 可疑
  - >6 个 IP → 🚨 多人共享
- 🎬 **访问的视频站**（YouTube、Netflix、TikTok、B 站、爱奇艺、Pornhub 等）
- 📥 **访问的下载站**（Steam、百度网盘、MEGA、Google Drive、迅雷等）
- 🔝 该端口访问最多的 5 个域名
- 每次运行会把当前下行流量存到快照文件，供下次计算「今日新增」

报告会先在终端以纯文本打印，然后（若配置了 Telegram）推送到指定聊天。

---

## 运行环境要求

- **操作系统**：Linux（已安装并运行 3X-UI 面板的服务器）
- **权限**：需要 **root** 运行（要读取 `/etc/x-ui/` 数据库、写入 `/root/` 快照）
- **依赖命令**：`bash`、`sqlite3`、`curl`、`awk`、`grep`、`sed`、`sort`、`uniq`

安装依赖（Debian / Ubuntu）：

```bash
apt update && apt install -y sqlite3 curl gawk grep coreutils
```

安装依赖（CentOS / RHEL）：

```bash
yum install -y sqlite curl gawk grep coreutils
```

---

## 涉及的文件路径

脚本顶部的变量决定了它读写哪些文件，按需修改：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `LOG` | `/usr/local/x-ui/access.log` | x-ui 的访问日志（用于识别域名 / IP） |
| `DB` | `/etc/x-ui/x-ui.db` | x-ui 的 SQLite 数据库（流量数据来源） |
| `SNAP` | `/root/.xui_snap` | 流量快照文件，用于计算两次巡检之间的增量 |
| `TG_TOKEN` | （脚本内写死） | Telegram Bot Token |
| `TG_CHAT` | （脚本内写死） | Telegram Chat ID（接收消息的人/群） |

> 注意：脚本依赖 x-ui 的「访问日志」功能。请在 3X-UI 面板的 **「Xray 设置 / 日志」** 里把 access log 路径设为 `/usr/local/x-ui/access.log` 并开启，否则视频站/下载站/IP 识别会为空。

---

## 使用步骤

### 1. 上传脚本到服务器

把 `xui_scan_all.sh` 放到服务器上，例如 `/root/`：

```bash
# 例如用 scp 从本地上传
scp xui_scan_all.sh root@你的服务器IP:/root/
```

### 2. 赋予可执行权限

```bash
chmod +x /root/xui_scan_all.sh
```

### 3. 配置 Telegram（可选但推荐）

打开脚本，修改这两行为你自己的值：

```bash
TG_TOKEN="你的BotToken"
TG_CHAT="你的ChatID"
```

- **获取 Bot Token**：在 Telegram 里找 [@BotFather](https://t.me/BotFather)，发送 `/newbot` 创建机器人，它会给你一串 Token。
- **获取 Chat ID**：先给你的机器人发一条消息，然后访问
  `https://api.telegram.org/bot<你的Token>/getUpdates`，在返回内容里找到 `chat":{"id": ...}`。

> 如果把 `TG_TOKEN` 留空（`TG_TOKEN=""`），脚本只在终端打印，不推送 Telegram。

### 4. 手动运行一次

```bash
bash /root/xui_scan_all.sh
# 或
/root/xui_scan_all.sh
```

> 第一次运行因为没有历史快照，「今日新增」会从 0 开始计算；从第二次起才会有真实的增量对比。

### 5. 设置定时巡检（可选）

用 `cron` 让它每天定时运行。编辑 crontab：

```bash
crontab -e
```

加入一行（例如每天早上 9:00 巡检一次）：

```cron
0 9 * * * /root/xui_scan_all.sh >> /var/log/xui_scan.log 2>&1
```

如果想计算「真正的每日增量」，建议**每天只跑一次**（快照按运行间隔累计）。

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

## ⚠️ 安全注意事项（务必阅读）

1. **不要把含有真实 Token 的脚本提交到公开 GitHub。** 当前脚本里写死了 Bot Token 和 Chat ID，一旦泄露，别人就能控制你的机器人。
   - 如果已经泄露过，请用 @BotFather 的 `/revoke` 重新生成 Token。
2. **推荐改成从环境变量读取**，避免把密钥写在代码里：

   ```bash
   TG_TOKEN="${TG_TOKEN:-}"
   TG_CHAT="${TG_CHAT:-}"
   ```

   然后运行时通过环境变量传入：

   ```bash
   TG_TOKEN="你的Token" TG_CHAT="你的ChatID" /root/xui_scan_all.sh
   ```

3. 脚本会把数据库**临时复制**到 `/tmp/.xui_ro.db` 进行只读查询，运行结束后会删除临时文件，不会修改原始数据库。

---

## 常见问题

**Q：提示「找不到数据库 /etc/x-ui/x-ui.db」**
A：说明数据库路径不对。用 `find / -name x-ui.db 2>/dev/null` 找到真实路径，修改脚本里的 `DB` 变量。

**Q：视频站 / 下载站 / IP 都显示「无」或 0**
A：access log 没开或路径不对。检查 3X-UI 面板里的 Xray 日志设置，确认 `/usr/local/x-ui/access.log` 存在且在记录。

**Q：报错 `sqlite3: command not found`**
A：没装 sqlite3，按上面「运行环境要求」安装依赖。

**Q：Telegram 没收到消息**
A：检查 Token / Chat ID 是否正确，服务器能否访问 `api.telegram.org`（部分网络需要代理）。
