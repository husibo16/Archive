#!/usr/bin/env bash
# ============================================================
# Tailscale 一键安装与自维护脚本（生产级智能增强版）
# 适配系统: Debian / Ubuntu（含 Ubuntu 24.10 Oracular / Debian 12+）
# 功能: 自动安装 Tailscale、配置仓库源、启动服务、自愈维护、日志轮换
# 作者: 胡博涵 实践版（2025）
# 版本: v1.2（智能时区与自检版）
# ============================================================

set -euo pipefail
trap 'echo -e "\033[1;31m[错误]\033[0m 安装过程中出现异常，脚本已中断。请检查日志：${LOG_FILE}"; exit 1' ERR

# === 可配置参数 ===
LOG_FILE="/var/log/tailscale_install.log"
MAINT_SCRIPT="/usr/local/bin/tailscale-maintenance.sh"
MAINT_SERVICE="/etc/systemd/system/tailscale-maintenance.service"
MAINT_TIMER="/etc/systemd/system/tailscale-maintenance.timer"
RETRY_COUNT=3
RETRY_DELAY=2
RUN_HOUR="03:00:00"  # 本地时间凌晨三点执行

# === 彩色输出函数 ===
info()    { echo -e "\033[1;34m[信息]\033[0m $1"; }
success() { echo -e "\033[1;32m[成功]\033[0m $1"; }
warn()    { echo -e "\033[1;33m[警告]\033[0m $1"; }
error()   { echo -e "\033[1;31m[错误]\033[0m $1"; }

# === 日志重定向 ===
exec > >(tee -a "$LOG_FILE") 2>&1

# === 重试函数 ===
retry() {
  local n=1
  until "$@"; do
    if (( n >= RETRY_COUNT )); then
      error "命令多次失败：$*"
      return 1
    fi
    warn "命令失败，${RETRY_DELAY}s 后重试 ($n/${RETRY_COUNT})..."
    sleep "$RETRY_DELAY"
    ((n++))
  done
}

# === 初始化与依赖检查 ===
info "检查系统依赖..."
apt update -y >/dev/null 2>&1 || true
apt install -y curl sudo ca-certificates gnupg lsb-release >/dev/null 2>&1
success "依赖检查完成。"

# === 检测系统 ===
info "检测系统环境..."
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)
success "系统识别为：${DISTRO^} ($CODENAME)"

# === 检测时区 ===
TIMEZONE=$(timedatectl show -p Timezone --value 2>/dev/null || echo "Etc/UTC")
success "当前系统时区：${TIMEZONE}"

# === 添加 Tailscale 软件源 ===
info "添加 Tailscale 软件源..."
retry bash -c "
curl -fsSL https://pkgs.tailscale.com/stable/${DISTRO}/${CODENAME}.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null &&
curl -fsSL https://pkgs.tailscale.com/stable/${DISTRO}/${CODENAME}.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
"

# === 安装 Tailscale ===
info "更新系统并安装 tailscale..."
retry apt update -y
retry apt install -y tailscale

# === 启动并启用 tailscaled ===
info "启动并启用 tailscaled 服务..."
systemctl enable tailscaled
systemctl restart tailscaled

# === 登录检测 ===
if ! tailscale status >/dev/null 2>&1; then
  info "首次登录：请在浏览器中授权。"
  sudo tailscale up
else
  success "Tailscale 已连接。"
fi

# === 创建自动维护脚本 ===
info "创建自动维护脚本..."
cat > "$MAINT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
# 自动维护脚本：每日重启 tailscaled 并记录状态
set -euo pipefail
LOG="/var/log/tailscale_maintenance.log"

mkdir -p /var/log
touch "$LOG"
chown root:adm "$LOG"
chmod 640 "$LOG"

echo "[$(date '+%F %T')] 开始 Tailscale 自检..." >> "$LOG"
systemctl restart tailscaled
sleep 3

if ! tailscale status >/dev/null 2>&1; then
  echo "[$(date '+%F %T')] ❌ tailscaled 重启失败！" >> "$LOG"
else
  echo "[$(date '+%F %T')] ✅ tailscaled 正常运行。" >> "$LOG"
fi
EOF

chmod +x "$MAINT_SCRIPT"
success "维护脚本已创建：$MAINT_SCRIPT"

# === 创建 systemd 服务与定时任务 ===
info "创建 systemd 定时维护任务..."
cat > "$MAINT_SERVICE" <<EOF
[Unit]
Description=Tailscale 自动维护服务
After=network-online.target

[Service]
Type=oneshot
ExecStart=$MAINT_SCRIPT
EOF

cat > "$MAINT_TIMER" <<EOF
[Unit]
Description=每日运行 Tailscale 维护任务（时区：$TIMEZONE）

[Timer]
OnCalendar=*-*-* ${RUN_HOUR}
Persistent=true
AccuracySec=5m

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now tailscale-maintenance.timer
success "定时维护任务已启用（每日 ${RUN_HOUR} 自动执行）"

# === 初始化维护日志文件（防止首次空缺） ===
if [ ! -f /var/log/tailscale_maintenance.log ]; then
  touch /var/log/tailscale_maintenance.log
  chown root:adm /var/log/tailscale_maintenance.log
  chmod 640 /var/log/tailscale_maintenance.log
  echo "[$(date '+%F %T')] 日志文件初始化完成。" >> /var/log/tailscale_maintenance.log
  success "已创建维护日志文件：/var/log/tailscale_maintenance.log"
fi

# === 启用日志自动轮换 ===
info "配置日志自动轮换..."
cat > /etc/logrotate.d/tailscale-maintenance <<'EOF'
/var/log/tailscale_maintenance.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 640 root adm
    postrotate
        systemctl kill -s HUP tailscaled >/dev/null 2>&1 || true
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
success "日志自动轮换配置已启用（每周压缩并保留 4 周记录）。"

# === 首次自检 ===
info "执行首次自检..."
bash "$MAINT_SCRIPT"
success "首次自检完成，日志已写入 /var/log/tailscale_maintenance.log"

# === 完成提示 ===
success "✅ Tailscale 安装与维护配置完成！"
echo "-----------------------------------------"
echo " 服务状态: systemctl status tailscaled"
echo " IP 查看:   tailscale ip -4"
echo " 日志文件:  /var/log/tailscale_maintenance.log"
echo " 定时任务:  tailscale-maintenance.timer (每日 ${RUN_HOUR} 执行)"
echo "-----------------------------------------"
echo ""
info "如需退出登录，可执行：tailscale logout"
warn "若为远程服务器，请考虑禁用 key 过期："
echo "  tailscale up --authkey=tskey-xxxx --reset --accept-routes"
echo ""
success "安装日志已保存至：${LOG_FILE}"
