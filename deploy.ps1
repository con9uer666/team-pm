# 部署脚本 - 在本地 Windows PowerShell 中执行
# 用法: 在 e:\PROJECTS\app 目录下执行 .\deploy.ps1
# 前提: 已执行过 deploy-setup.sh 初始化服务器

$SERVER = "ubuntu@49.233.180.22"
$REMOTE_DIR = "/opt/app"

Write-Host "=== 1. 打包项目文件 ===" -ForegroundColor Green

# 创建临时目录用于打包
$tempDir = "$env:TEMP\app-deploy"
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir | Out-Null

# 复制需要的文件
Copy-Item "docker-compose.yml" "$tempDir\"

# 后端
New-Item -ItemType Directory -Path "$tempDir\backend" | Out-Null
Copy-Item "backend\package.json" "$tempDir\backend\"
Copy-Item "backend\package-lock.json" "$tempDir\backend\"
Copy-Item "backend\tsconfig.json" "$tempDir\backend\"
Copy-Item "backend\tsconfig.build.json" "$tempDir\backend\"
Copy-Item "backend\nest-cli.json" "$tempDir\backend\"
Copy-Item "backend\Dockerfile" "$tempDir\backend\"
Copy-Item "backend\.dockerignore" "$tempDir\backend\"
Copy-Item -Recurse "backend\src" "$tempDir\backend\src"

# 前端
New-Item -ItemType Directory -Path "$tempDir\frontend" | Out-Null
Copy-Item "frontend\package.json" "$tempDir\frontend\"
Copy-Item "frontend\package-lock.json" "$tempDir\frontend\"
Copy-Item "frontend\tsconfig.json" "$tempDir\frontend\"
Copy-Item "frontend\tsconfig.app.json" "$tempDir\frontend\"
Copy-Item "frontend\tsconfig.node.json" "$tempDir\frontend\"
Copy-Item "frontend\vite.config.ts" "$tempDir\frontend\"
Copy-Item "frontend\index.html" "$tempDir\frontend\"
Copy-Item "frontend\Dockerfile" "$tempDir\frontend\"
Copy-Item "frontend\.dockerignore" "$tempDir\frontend\"
Copy-Item "frontend\nginx.conf" "$tempDir\frontend\"
Copy-Item -Recurse "frontend\src" "$tempDir\frontend\src"
if (Test-Path "frontend\public") {
    Copy-Item -Recurse "frontend\public" "$tempDir\frontend\public"
}

Write-Host "=== 2. 上传到服务器 ===" -ForegroundColor Green

# 用 scp 上传
scp -r "$tempDir\*" "${SERVER}:${REMOTE_DIR}/"

Write-Host "=== 3. 在服务器上构建并启动 ===" -ForegroundColor Green

# 在服务器上创建 .env 并启动
ssh $SERVER "cd /opt/app && echo 'DB_PASSWORD=Doudou2006' > .env && echo 'JWT_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4' >> .env && docker compose down 2>/dev/null; docker compose up -d --build && echo '' && echo '=== 等待服务启动 ===' && sleep 15 && docker compose ps && echo '' && echo '访问地址: http://49.233.180.22:8080'"

# 清理临时文件
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "=== 部署完成! ===" -ForegroundColor Green
Write-Host "访问地址: http://49.233.180.22:8080" -ForegroundColor Cyan
