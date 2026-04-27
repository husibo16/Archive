# setup-xboard

## 下载主脚本（xboard-restart）
```
cd /usr/local/bin
sudo wget -O xboard-restart https://raw.githubusercontent.com/husibo16/setup-xboard/main/xboard-restart
sudo chmod +x xboard-restart

```
## 下载安装器（setup-xboard-timer.sh）
```
cd /opt
sudo wget -O setup-xboard-timer.sh https://raw.githubusercontent.com/husibo16/setup-xboard/main/setup-xboard-timer.sh
sudo chmod +x setup-xboard-timer.sh

```

## 一键安装 systemd 定时任务

```
sudo /opt/setup-xboard-timer.sh

```
> 执行后会：
> 
> 在 /etc/systemd/system/ 自动创建 .service 和 .timer
> 
> 启用并立即启动定时器
> 
> 每天凌晨 3 点自动运行 /usr/local/bin/xboard-restart
