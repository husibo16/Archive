# 🧭 FRP 一键部署脚本使用指南

本指南介绍如何使用仓库中的 `bin/install-frps.sh` 与 `bin/install-frpc.sh`，在 VPS + 家庭服务器 间快速搭建安全稳定的 FRP 内网穿透服务。

## 前置条件
- 系统：常见 Linux 发行版（Ubuntu / Debian / CentOS 等）
- 目标系统需为常见的 Linux 发行版，并使用 **systemd** 管理服务。
- 权限：以 `root` 运行（或 `sudo -i` 切换）
- 依赖：需预装 `curl、tar、install`（通常系统自带）

# 🚀 一、部署 FRP 服务端（VPS）

### 1-1. 登录拥有公网 IP 的 VPS。
### 1-2. 下载并安装：

   ```bash
   curl -fsSL https://raw.githubusercontent.com/husibo16/frp-nps/main/bin/install-frps.sh -o install-frps.sh
   chmod +x install-frps.sh
   sudo ./install-frps.sh
   ```

### 1-3. 执行后：
 - 安装位置：/usr/local/bin/frps
 - 默认配置：/etc/frp/frps.toml
 - 服务文件：/etc/systemd/system/frps.service
 - 自动启动并开机自启

### 1-4. 如需自定义端口或认证信息，可在运行脚本前通过环境变量覆盖：
 - 后续改动可直接编辑 /etc/frp/frps.toml 并重启服务。

```bash
   #======================
   # 基础监听端口
   #======================
   FRPS_BIND_PORT=7000      
   # 👉 客户端连接的主端口，需开放防火墙（默认7000）
   # ✅ 生产推荐：6000~8999 间任意空闲端口，如 7000、7100 等。

   #======================
   # Web 管理面板（Dashboard）
   #======================
   FRPS_WEB_ADDR=0.0.0.0    
   # 👉 监听地址（0.0.0.0 表示允许所有来源访问）
   # ✅ 生产推荐：保留默认；若启用防火墙，可仅放行管理 IP。

   FRPS_WEB_PORT=7500       
   # 👉 Web 面板端口：http://VPS_IP:7500
   # ✅ 生产推荐：非必须暴露公网，可用 Cloudflare Tunnel 反代访问。

   FRPS_WEB_USER=admin      
   # 👉 登录用户名
   # ✅ 生产推荐：改成自定义用户名。

   FRPS_WEB_PASS='changeme'
   # 👉 登录密码
   # ✅ 必改！推荐复杂度高的强密码（frpSecureToken@2025）。

   #======================
   # 认证配置
   #======================
   FRPS_AUTH_METHOD=token   
   # 👉 认证方式，常用 token 模式（默认）
   # ✅ 推荐保留 token，OIDC 仅企业场景使用。

   FRPS_TOKEN='changeme'
   # 👉 通信口令，客户端必须一致
   # ✅ 必改！长度≥12 且混合大小写符号（frpSecureToken@2025）。
   # 随机密码生成命令生产级推荐（安全、简洁、跨环境）openssl rand -base64 24 | tr -d '\n' | fold -w 16 | head -n 1


   #======================
   # 日志配置
   #======================
   FRPS_LOG_PATH=/var/log/frps.log
   # 👉 日志文件路径
   # ✅ 推荐路径：/var/log/frps.log（独立于系统日志）

   FRPS_LOG_LEVEL=info
   # 👉 日志等级(trace/debug/info/warn/error)
   # ✅ 生产推荐：info（必要时可改为 warn）

   #======================
   # Prometheus 监控
   #======================
   FRPS_ENABLE_PROMETHEUS=true
   # 👉 是否启用 /metrics 端点
   # ✅ 推荐：true（方便监控流量/连接）
```

### 1-5. 修改配置与重启服务

```bash
   # 打开 frps 配置文件（服务端配置）
   sudo nano /etc/frp/frps.toml

   # 让 systemd 重新加载配置文件
   sudo systemctl daemon-reload

   # 重启 frps 服务以使修改生效
   sudo systemctl restart frps

   # 查看 frps 当前运行状态
   sudo systemctl status frps

   # 实时日志
   sudo journalctl -u frps -f

```
>🔐 建议：首次安装后务必修改默认 token 和面板密码。

## 🖥️ 二、部署 FRP 客户端（家庭服务器）

### 2-1. 在需要穿透的家庭服务器上执行以下步骤。
### 2-2. 下载并安装：

   ```bash
   curl -fsSL https://raw.githubusercontent.com/husibo16/frp-nps/main/bin/install-frpc.sh -o install-frpc.sh
   chmod +x install-frpc.sh
   sudo ./install-frpc.sh
   ```

### 2-3. 自定义配置变量：

   ```bash
   #======================
   # frpc 配置文件（客户端）
   #======================
   # 服务端连接信息
   #--------------------------------
   serverAddr = "10.168.9.22"
   # 👉 填写 VPS 的公网 IP 或域名（运行 frps 的主机）。
   # ✅ 生产推荐：使用域名（例如 frp.example.com）+ DDNS 或 Cloudflare 动态解析，方便 IP 变更。
   # ❌ 不要填家里的内网地址，也不要填 127.0.0.1！

   serverPort = 7000
   # 👉 frps 服务端监听端口，对应 /etc/frp/frps.toml 中的 bindPort。
   # ✅ 默认 7000，可改成 6000~8999 任意空闲端口（服务端和客户端必须一致）。

   #--------------------------------
   # 认证配置
   #--------------------------------
   auth.method = "token"
   # 👉 认证方式，常见为 token（默认）。
   # ✅ 推荐：保持 token 模式；OIDC 仅适合企业集成环境。

   auth.token = "changeme"
   # 👉 通信密钥（客户端与服务端必须一致）。
   # ⚠️ 默认值 changeme 极不安全，请修改！
   # ✅ 推荐：强随机字符串，如 frpSecureToken@2025 或生成随机 UUID。
   # 随机密码生成命令生产级推荐（安全、简洁、跨环境）openssl rand -base64 24 | tr -d '\n' | fold -w 16 | head -n 1

   #--------------------------------
   # 代理隧道配置（每个 [[proxies]] 代表一条穿透规则）
   #--------------------------------
   [[proxies]]
   name = "xboard"
   # 👉 隧道名称（自定义标识）。
   # ✅ 推荐与应用名一致，如 “xboard”、“btpanel”、“nas”、“ssh”。

   type = "tcp"
   # 👉 穿透类型：tcp / udp / http / https 等。
   # ✅ 推荐根据目标服务类型选择：
   #    - Web 服务（如宝塔、Xboard）：tcp
   #    - SSH 远程管理：tcp
   #    - 游戏/流媒体：udp

   localIP = "127.0.0.1"
   # 👉 本地目标 IP，通常为 localhost。
   # ✅ 推荐保持 127.0.0.1（除非目标服务运行在其他局域网机器上）。

   localPort = 7001
   # 👉 本地被代理的服务端口。
   # ✅ 示例：Xboard 面板运行在 7001 端口，则这里填 7001；
   #    宝塔默认 8888，nginx 默认 80 或 443。

   remotePort = 7001
   # 👉 VPS 上对应的外网访问端口（即外部访问 http://VPS_IP:remotePort）。
   # ✅ 推荐：使用 9000~9999 段（避免和服务端 bindPort 冲突）。
   #    例如 remotePort = 9001，则访问 http://VPS_IP:9001。
   # ⚠️ 若 VPS 上已有端口占用，需修改为其他未被占用的端口。
   ```

### 2-4. 修改配置与重启服务。
   ```bash
   # 打开 frpc 配置文件（家庭服务器配置）
   sudo nano /etc/frp/frps.toml

   # 让 systemd 重新加载配置文件
   sudo systemctl daemon-reload

   # 重启 frps 服务以使修改生效
   sudo systemctl restart frpc

   # 查看 frps 当前运行状态
   sudo systemctl status frpc

   # 实时日志
   sudo journalctl -u frpc -f

   ```
### 2-4.1. 日志示例（成功）

   ```bash
   [I] [client/service.go:317] login to server success
   [I] [proxy/proxy_manager.go:177] proxy added: [xboard]

   ```
   
## 🧰 三、常用命令

### 3-1. 基本运维命令
   
   ```bash
# 启动服务
sudo systemctl start frps
sudo systemctl start frpc

# 停止服务
sudo systemctl stop frps
sudo systemctl stop frpc

# 重启服务（修改配置后必须执行）
sudo systemctl restart frps
sudo systemctl restart frpc

# 查看服务状态
sudo systemctl status frps
sudo systemctl status frpc

# 设置开机自启
sudo systemctl enable frps
sudo systemctl enable frpc

# 取消开机自启
sudo systemctl disable frps
sudo systemctl disable frpc

# 重新加载 systemd 配置（修改 service 文件后）
sudo systemctl daemon-reload

   ```
### 3-2. 日志与监控
```bash
# 查看实时日志（推荐）
sudo journalctl -u frps -f
sudo journalctl -u frpc -f

# 查看最近 100 行日志
sudo journalctl -u frps -n 100
sudo journalctl -u frpc -n 100

# 查看特定日期的日志
sudo journalctl -u frps --since "2025-10-17"

# 日志文件（如配置中指定）
sudo tail -f /var/log/frps.log
```
### 3-3.配置与版本
```bash
# 编辑配置文件
sudo nano /etc/frp/frps.toml
sudo nano /etc/frp/frpc.toml

# 检查配置文件路径
sudo ls -l /etc/frp/

# 查看 FRP 版本
/usr/local/bin/frps --version
/usr/local/bin/frpc --version

# 自动检查服务健康状态（可放入 crontab）
*/5 * * * * systemctl is-active frps frpc || systemctl restart frps frpc
```
### 3-4.调试与网络测试
```bash
# 检查服务端口监听
sudo ss -tulpn | grep frps
sudo ss -tulpn | grep frpc

# 确认 FRP 转发端口是否监听
sudo ss -tulpn | grep 6001   # 示例：Xboard 远程端口

# 测试内网目标是否可访问
curl 127.0.0.1:7001

# 测试公网访问是否成功
curl www.jbrx16.top:6001

# 检查防火墙放行情况
sudo ufw status
sudo ufw allow 6818/tcp
sudo ufw allow 6001/tcp
sudo ufw allow 7500/tcp   # Dashboard（如启用）
```

## 🧩一键彻底卸载/清理 FRP 的完整命令合集

若需卸载，可执行：

```bash
# 停止并禁用 frps / frpc 服务（同时取消开机自启）
sudo systemctl disable --now frps frpc 2>/dev/null

# 删除二进制文件（主程序）
sudo rm -f /usr/local/bin/frps /usr/local/bin/frpc

# 删除 systemd 服务文件
sudo rm -f /etc/systemd/system/frps.service /etc/systemd/system/frpc.service

# 删除 FRP 配置目录
sudo rm -rf /etc/frp

# 删除服务软链接（防止 systemd 残留）
sudo rm -f /etc/systemd/system/multi-user.target.wants/frps.service
sudo rm -f /etc/systemd/system/multi-user.target.wants/frpc.service

# 删除日志文件
sudo rm -f /var/log/frps.log /var/log/frpc.log

# 清理临时安装文件（如手动解压的包）
sudo rm -rf /tmp/frp* /root/frp* /home/*/frp*

# 刷新 systemd 管理器配置并清理失败状态
sudo systemctl daemon-reload
sudo systemctl reset-failed

# 验证清理结果（应无输出或仅有内核模块/locale 残留）
sudo find / -name "frp*" 2>/dev/null
```
🧠 可选进一步清理（非必须）

如果之前设置了 dashboard 或反代，可以执行：
```bash
# 移除 Nginx 反代配置（如果存在）
sudo rm -f /etc/nginx/sites-enabled/frps.conf /etc/nginx/sites-available/frps.conf
sudo nginx -t && sudo systemctl reload nginx
```
✅ 验证卸载成功
```bash
sudo systemctl list-units --type=service | grep frp
```

应无任何输出。
再检查：
```bash
sudo find / -name "frp*" 2>/dev/null

# 如果只剩：

/usr/lib/modules/.../frpw.ko.zst
/usr/share/locale/frp
```
这两个是 Linux 内核模块和系统语言文件，与 FRP 无关，可保留

> ⚠️ 卸载脚本未集成于仓库中，上述步骤需按需手动执行。


## 🧩 五、生产环境建议汇总表

| 配置项                 | 推荐值         | 说明         |
| ------------------- | ----------- | ---------- |
| `bindPort`          | 6000~8999   | 主连接端口，防扫描  |
| `auth.token`        | 长度≥12 强随机   | 必改，客户端需一致  |
| `webServer.port`    | 7500（仅内网访问） | 管理面板端口     |
| `FRPC_REMOTE_PORT`  | 9000~9999   | VPS 对外暴露端口 |
| `log.level`         | info        | 推荐生产等级     |
| `enablePrometheus`  | true        | 可供监控采集     |
| `systemctl restart` | 每次改配置后执行    | 确保生效       |




