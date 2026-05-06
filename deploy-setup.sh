#!/bin/bash
# 服务器初始化脚本 - 在服务器上执行一次
# 用法: ssh ubuntu@49.233.180.22 后粘贴执行

set -e

echo "=== 1. 安装 Docker ==="
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 让 ubuntu 用户可以直接用 docker
sudo usermod -aG docker ubuntu

echo "=== 2. 创建项目目录 ==="
sudo mkdir -p /opt/app
sudo chown ubuntu:ubuntu /opt/app

echo "=== 3. 配置 swap (1GB) ==="
if [ ! -f /swapfile ]; then
  sudo fallocate -l 1G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo "=== 4. 开放防火墙端口 ==="
echo "请在腾讯云控制台 -> 防火墙 中开放 8080 端口"

echo "=== 完成! ==="
echo "请退出 SSH 重新登录(让 docker 组生效)，然后执行部署脚本上传代码"
