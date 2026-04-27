#!/bin/bash
# ===============================================================
# 一键安装 Xboard + MariaDB 自动重启 systemd 定时任务
# 作者: 胡博涵
# 说明: 每天凌晨 3 点自动执行 /usr/local/bin/xboard-restart
# ===============================================================

set -e

SERVICE_PATH="/etc/systemd/system/xboard-restart.service"
TIMER_PATH="/etc/systemd/system/xboard-restart.timer"
SCRIPT_PATH="/usr/local/bin/xboard-restart"
LOG_FILE="/var/log/xboard-restart.log"

echo "=== 🧩 开始安装 Xboard 自动重启定时任务 ==="

# 检查主脚本存在且可执行
if [ ! -x "$SCRIPT_PATH" ]; then
  echo "❌ 未找到主脚本，请先创建: $SCRIPT_PATH"
  exit 1
fi

# === 1️⃣ 创建 systemd 服务单元 ===
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Xboard + MariaDB Daily Restart
After=docker.service mariadb.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

# === 2️⃣ 创建定时器单元 ===
cat > "$TIMER_PATH" <<EOF
[Unit]
Description=Run xboard-restart daily at 3:00

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

# === 3️⃣ 启用并启动定时器 ===
systemctl daemon-reload
systemctl enable --now xboard-restart.timer

# 延迟 2 秒以便 systemd 刷新状态缓存
sleep 2

# === 4️⃣ 状态校验 ===
echo
echo "✅ 安装完成。当前定时任务状态："
systemctl list-timers --all | grep xboard-restart || echo "⚠️ 未在定时列表中，请手动检查 systemctl status xboard-restart.timer"
echo
echo "📂 日志路径: $LOG_FILE"
echo "▶️ 手动执行命令: xboard-restart"
echo "🔎 查看定时器状态: systemctl status xboard-restart.timer"
echo "📜 查看执行日志: journalctl -u xboard-restart.service -n 20"
echo "==============================================="
