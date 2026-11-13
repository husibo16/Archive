# Archive

不再使用的脚本和项目，留作参考。这里的内容不维护，也不保证还能直接使用。

## 脚本

| 目录 | 内容 |
|---|---|
| `bbrv1/` | BBR 加速脚本 |
| `Cloudflare_Tunnel/` | Cloudflare Tunnel |
| `frp-nps/` | frp / nps 内网穿透 |
| `MariaDB/` | MariaDB |
| `setup-xboard/` | XBoard 安装 |
| `Snipe-IT/` | Snipe-IT |
| `Tailscale/` | Tailscale |

## 归档的仓库（2026-11-13）

下面这些原本是独立仓库，已经不用（另有重写的版本）。每个目录是原仓库最后一个版本的文件，**不含提交历史**；原仓库在 GitHub 上设为只读归档，历史仍在那里。

| 目录 | 原仓库 | 版本 | 说明 |
|---|---|---|---|
| `Epaydocker/` | husibo16/Epaydocker | 79344fa（2026-11-12） | 易支付一键 Docker 部署 |
| `Epay-docker/` | husibo16/Epay-docker | debc0c1（2026-11-12） | 易支付，与 Epaydocker 基本相同 |
| `vmqfox/` | husibo16/vmqfox | f20d4ef（2026-11-12） | V 免签（前后端一体） |
| `vmqfox-backend-docker/` | husibo16/vmqfox-backend-docker | 0ecf19b（2026-11-12） | V 免签后端 + Docker，后端代码与 vmqfox 相同 |
| `vmqfox-frontend/` | husibo16/vmqfox-frontend（fork 自 hulisang/vmqfox-frontend） | 6ffba54（2026-11-12） | V 免签前端 |
| `wireguard/` | husibo16/wireguard | badae8b（2025-11-22） | wg-easy |

五个支付目录（Epay*、vmqfox*）包含 2026-11-12 安全核查的修复：vmqfox 后台接口要求登录、未付款订单不再生成回调签名、去掉可读任意文件的通配路由、令牌签名与过期、推送防重放；Epay 的 Docker 部署不再把数据库/Redis 端口和敏感目录暴露在外、定时任务可以运行、密码比较用 `hash_equals`。这些修复只在这里，原仓库没有。

**安全提示**：vmqfox-backend-docker 原仓库的提交历史里有两个数据库密码（已不在当前文件里）；用到过这两个密码的地方都应更换。
