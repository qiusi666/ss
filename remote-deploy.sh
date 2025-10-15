#!/bin/bash

# 闲鱼自动回复系统远程一键部署脚本
# 集成了Layui前端和PearAdmin后台

echo "==================================================="
echo "闲鱼自动回复系统集成版 - 远程一键部署"
echo "==================================================="

# 检查必要工具
for cmd in curl git docker docker-compose; do
    if ! command -v $cmd &> /dev/null; then
        echo "错误: 未安装 $cmd，请先安装后再运行此脚本"
        echo "您可以参考官方文档安装: "
        echo "- Docker: https://docs.docker.com/get-docker/"
        echo "- Git: https://git-scm.com/downloads"
        echo "- curl: https://curl.se/download.html"
        exit 1
    fi
done

# 创建临时目录
TEMP_DIR=$(mktemp -d)
echo "创建临时工作目录: $TEMP_DIR"

# 克隆代码仓库
echo "开始下载源码..."
git clone https://github.com/zhinianboke/xianyu-auto-reply.git $TEMP_DIR

# 进入项目目录
cd $TEMP_DIR

# 检查是否为集成版本
if [ ! -f "docker-compose-integrated.yml" ]; then
    echo "下载的源码中没有找到集成版配置文件，正在下载必要文件..."
    
    # 下载集成版所需文件
    curl -fsSL https://raw.githubusercontent.com/zhinianboke/xianyu-auto-reply/main/Dockerfile-integrated -o Dockerfile-integrated
    curl -fsSL https://raw.githubusercontent.com/zhinianboke/xianyu-auto-reply/main/docker-compose-integrated.yml -o docker-compose-integrated.yml
    curl -fsSL https://raw.githubusercontent.com/zhinianboke/xianyu-auto-reply/main/entrypoint-integrated.sh -o entrypoint-integrated.sh
    chmod +x entrypoint-integrated.sh
    
    # 创建nginx配置目录
    mkdir -p nginx/ssl
    curl -fsSL https://raw.githubusercontent.com/zhinianboke/xianyu-auto-reply/main/nginx/integrated-nginx.conf -o nginx/integrated-nginx.conf
fi

# 创建环境变量文件
if [ ! -f ".env" ]; then
    echo "创建环境变量配置..."
    cat > .env << EOL
# 基础配置
TZ=Asia/Shanghai
DEBUG=false

# 端口配置
API_PORT=8000
ADMIN_PORT=5000
HTTP_PORT=80
HTTPS_PORT=443

# 数据库配置
DB_PATH=/app/data/xianyu_data.db
FLASK_SQLALCHEMY_DATABASE_URI=sqlite:////app/data/admin.db

# 用户配置
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
FLASK_ADMIN_USERNAME=admin
FLASK_ADMIN_PASSWORD=admin123
JWT_SECRET_KEY=$(openssl rand -hex 32)
FLASK_SECRET_KEY=$(openssl rand -hex 32)

# 系统配置
MEMORY_LIMIT=1024
CPU_LIMIT=1.0
EOL
    echo "环境变量配置文件已创建"
fi

# 创建数据存储目录
mkdir -p data logs backups admin/static/admin/images admin/static/admin/css admin/static/admin/js

# 开始部署
echo "开始构建Docker镜像并启动容器..."
docker-compose -f docker-compose-integrated.yml up -d --build

# 检查容器状态
echo "等待容器启动..."
sleep 10

if docker-compose -f docker-compose-integrated.yml ps | grep -q "Up"; then
    echo "==================================================="
    echo "闲鱼自动回复系统集成版已成功部署!"
    echo "访问地址:"
    echo "- 原系统API: http://localhost:$(grep API_PORT .env | cut -d= -f2)"
    echo "- PearAdmin后台: http://localhost:$(grep ADMIN_PORT .env | cut -d= -f2)"
    echo "- 集成系统(通过Nginx): http://localhost:$(grep HTTP_PORT .env | cut -d= -f2)"
    echo ""
    echo "默认管理员账号: $(grep ADMIN_USERNAME .env | cut -d= -f2)"
    echo "默认管理员密码: $(grep ADMIN_PASSWORD .env | cut -d= -f2)"
    echo "==================================================="
    
    # 移动源码到最终目录
    INSTALL_DIR="$HOME/xianyu-auto-reply"
    echo "将项目文件移动到: $INSTALL_DIR"
    
    # 备份现有目录
    if [ -d "$INSTALL_DIR" ]; then
        mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$INSTALL_DIR"
    cp -r * "$INSTALL_DIR"
    cp -r .env "$INSTALL_DIR" 2>/dev/null || true
    
    echo "源码已保存到: $INSTALL_DIR"
    echo "您可以进入该目录进行后续管理"
else
    echo "错误: 容器启动失败，请检查日志"
    docker-compose -f docker-compose-integrated.yml logs
    exit 1
fi

echo "部署完成!"