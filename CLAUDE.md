# 项目记忆

## 项目概述

团队项目管理系统（RoboMaster 战队），NestJS 后端 + Vue 3 前端（Vant UI），移动端优先。

## 技术栈

- 后端: NestJS 11 + TypeORM + PostgreSQL 16 + Redis 7
- 前端: Vue 3 + Vite + Vant 4 + Pinia + Axios
- 部署: Docker Compose，4 个容器（postgres、redis、backend、frontend）

## 服务器信息

- IP: 49.233.180.22
- OS: Ubuntu 22.04（腾讯云轻量应用服务器）
- 配置: 2核 2GB RAM, 40GB SSD, 2Mbps 带宽
- SSH 用户: ubuntu
- 项目路径: /opt/app
- 访问地址: http://49.233.180.22:8080

## 部署流程

本地改完代码后：

```bash
git add -A && git commit -m "描述" && git push
```

SSH 到服务器更新：

```bash
ssh ubuntu@49.233.180.22
cd /opt/app && git pull && docker compose up -d --build
```

## GitHub 仓库

- 地址: https://github.com/con9uer666/team-pm (私有)
- 服务器通过 SSH Deploy Key 访问

## 数据库

- 数据库名: team_pm
- 用户: app_user
- 密码: Doudou2006
- 容器内 host: postgres（Docker 网络）

## 组织架构

- 兵种组(divisions): 步兵、英雄、工程
- 技术组(groups): 电控、机械
- 角色等级: 1=梯队员, 2=正式队员, 3=组长, 4=项管, 5=超管(保留), 6=指导老师

## 注意事项

- 前端构建跳过 vue-tsc 类型检查（Dockerfile 中用 `npx vite build`）
- 后端 DB_HOST 从环境变量读取，本地默认 localhost，Docker 中为 postgres
- 服务器 Docker 镜像加速: /etc/docker/daemon.json 配置了国内镜像源
- 不需要域名和备案，直接 IP+端口访问
- 防火墙需开放 8080 端口
- 高德 Web 服务 Key 放 `frontend/.env` 的 `VITE_AMAP_KEY`（gitignored）；docker compose 通过 build args 注入。服务器部署前先 `export VITE_AMAP_KEY=xxx` 再 `docker compose up -d --build`。控制台需开启「Web 服务」并绑定域名/IP 白名单。
