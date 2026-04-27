#!/usr/bin/env bash
# ============================================================
# Tailscale 自愈与维护修复脚本（生产安全版）
# 适配系统: Debian / Ubuntu
# 功能: 修复 tailscaled 自愈、日志轮换与定时任务问题
# 作者: 胡博涵 实践版（2025）
# 版本: v1.1
# ============================================================

set -euo pipefail

# === 彩色输出函数 ===
green() { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
red() { echo -e "\033[1;31m$*\033[0m"; }

# === 1️⃣ 启用 tailscaled 自愈机制 ===
echo "[步骤1] 启用 tailscaled 自愈机制..."
mkdir -p /etc/systemd/system/tailscaled.service.d

cat >/etc/systemd/system/tailscaled.service.d/override.conf <<'EOF'
[Service]
Restart=always
RestartSec=5s
EOF

systemctl daemon-reload
systemctl enable tailscaled >/dev/null 2>&1 || true
systemctl restart tailscaled

green "[OK] tailscaled 已设置自动重启（Restart=always, RestartSec=5s）"

# === 2️⃣ 修复 logrotate 的误杀行为 ===
echo "[步骤2] 修复 logrotate 配置..."
cat >/etc/logrotate.d/tailscale-maintenance <<'EOF'
/var/log/tailscale_maintenance.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 640 root adm
    postrotate
        systemctl reload-or-restart tailscaled >/dev/null 2>&1 || true
    endscript
}

/var/log/tailscale_install.log {
    weekly
    rotate 2
    compress
    missingok
    notifempty
    create 640 root adm
}
EOF

green "[OK] logrotate 已修复为安全 reload 模式。"

# === 3️⃣ 健康检查与自愈验证 ===
echo "[步骤3] 执行健康自检..."
systemctl restart tailscaled
sleep 6  # ⏳ 给 tailscaled 充分启动时间
if tailscale status 2>/dev/null | grep -q "Connected"; then
  green "[健康] tailscaled 已连接控制平面。"
elif tailscale status >/dev/null 2>&1; then
  yellow "[提示] tailscaled 已运行但尚未连接，请稍后再试 tailscale status。"
else
  red "[异常] tailscaled 重启失败，请检查 /var/log/tailscale_maintenance.log"
  exit 1
fi

# === 4️⃣ 检查定时任务状态 ===
echo "[步骤4] 检查定时任务状态..."
if systemctl list-timers --all | grep -q tailscale-maintenance.timer; then
  green "[OK] tailscale-maintenance.timer 已启用。"
else
  yellow "⚠️ 定时任务未启动，请运行：systemctl enable --now tailscale-maintenance.timer"
fi

# === 5️⃣ 总结信息 ===
echo ""
green "✅ 修复完成！当前状态摘要："
systemctl show tailscaled -p Restart,RestartSec | sed 's/^/  /'
systemctl is-active tailscaled >/dev/null && echo "  tailscaled 状态：运行中" || echo "  tailscaled 状态：未运行"
systemctl list-timers --all | grep tailscale-maintenance.timer || echo "  ⚠️ tailscale-maintenance.timer 未启用"
echo ""
green "日志文件位置：/var/log/tailscale_maintenance.log"
