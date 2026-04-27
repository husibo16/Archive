# MariaDB 一键安装与初始化脚本（兼容 MySQL 8.0）

> 适配系统：Debian / Ubuntu（含 Debian 13 Trixie）  
> 功能：自动安装 MariaDB、启用日志、创建全局管理员用户  
> 作者：胡博涵 实践版（2025）  
> 版本：v1.0

---

## 📖 功能简介

本脚本可在 **全新系统环境** 下自动完成以下工作：

1. 自动检测系统版本（支持 Debian / Ubuntu）  
2. 自动安装 `MariaDB Server` 与 `Client`  
3. 初始化 `root` 密码（安全配置）  
4. 创建业务数据库与具备全局权限的管理员账号  
5. 启用 **通用日志** 与 **慢查询日志**  
6. 自动备份原始配置文件并输出日志至 `/var/log/mysql_install.log`  
7. 支持远程连接（需手动修改配置项）  

> 💡 如果需要远程访问 MariaDB，请编辑配置文件：
> ```bash
> sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
> ```
> 将以下行：
> ```
> bind-address = 127.0.0.1
> ```
> 修改为：
> ```
> bind-address = 0.0.0.0
> ```
> 然后重启服务：
> ```bash
> sudo systemctl restart mariadb
> ```

---

## ⚙️ 默认配置

| 项目 | 默认值 | 说明 |
|------|---------|------|
| MariaDB 版本 | 兼容 MySQL 8.0 | 通过官方 `mariadb-server` 软件包安装 |
| root 密码 | `Root@123456` | 可在脚本顶部修改 |
| 新数据库名 | `xboard` | 可在脚本顶部修改 |
| 新用户名 | `xboard` | 拥有全局管理权限 |
| 新用户密码 | `3uA3iPqOwzNyUlMB` | 可自定义 |
| 日志目录 | `/var/log/mysql/` | 含通用日志与慢查询日志 |

---

## 🚀 使用方法

### 1️⃣ 下载脚本

```bash
wget -O install_mariadb.sh https://raw.githubusercontent.com/husibo16/MariaDB/main/install_mariadb.sh
```
2️⃣ 赋予执行权限并运行

```bash
chmod +x install_mariadb.sh
sudo ./install_mariadb.sh
```
⚠️ 说明：

./install_mariadb.sh 表示按照脚本首行指定的解释器（#!/usr/bin/env bash）执行；

若你想调试或不想改权限，也可用：
```bash
bash install_mariadb.sh
```
查看当前系统安装的 MariaDB 客户端版本

```bash
mariadb --version
```
## 🧩 登录与验证

1️⃣ 使用 root 用户登录（本地）
```bash
mysql -u root -p
```
> 然后输入安装脚本中设置的密码（默认是 Root@123456或无）。

2️⃣ 使用业务用户登录（本地或远程）
```bash
mysql -u xboard -p3uA3iPqOwzNyUlMB -h 127.0.0.1 -P 3306
```
>⚠️ 参数说明：
> - -u 用户名
> - -p 密码（安全性较低，建议手动输入）
> - -h 主机地址（127.0.0.1 为本机）
> - -P 端口号（默认 3306）
3️⃣ 登录后常用验证命令
- 查看所有数据库
```bash
SHOW DATABASES;
```
- 切换到指定数据库
```bash
USE xboard;
```
- 查看当前登录用户
```bash
SELECT USER(), CURRENT_USER();
```
- 查看权限
```bash
SHOW GRANTS FOR 'xboard'@'%';
```
4️⃣ 退出 MySQL

```bash
exit;
```
