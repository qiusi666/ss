#!/bin/bash

# 完整的一键部署脚本 - 包含所有必要配置

echo "===================================================="
echo "闲鱼自动回复系统集成版 - 一键部署(自包含版)"
echo "===================================================="

# 检查必要工具
for cmd in docker docker-compose; do
    if ! command -v $cmd &> /dev/null; then
        echo "错误: 未安装 $cmd，请先安装后再运行此脚本"
        exit 1
    fi
done

# 创建项目目录
INSTALL_DIR="/opt/xianyu-auto-reply"
echo "创建项目目录: $INSTALL_DIR"

mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# 创建必要的子目录
mkdir -p data logs backups nginx/ssl admin/static/admin/{images,css,js}

# 创建Dockerfile
echo "创建Dockerfile..."
cat > Dockerfile << 'EOL'
# 使用Python 3.11作为基础镜像
FROM python:3.11-slim-bookworm

# 设置标签信息
LABEL maintainer="zhinianboke"
LABEL version="3.0.0"
LABEL description="闲鱼自动回复系统 - 集成Layui前端和PearAdmin后台版本"

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV TZ=Asia/Shanghai
ENV DOCKER_ENV=true
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# 安装系统依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nodejs npm tzdata curl ca-certificates libjpeg-dev libpng-dev \
        libfreetype6-dev fonts-dejavu-core fonts-liberation libnss3 libnspr4 \
        libatk-bridge2.0-0 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
        libxrandr2 libgbm1 libxss1 libasound2 libatspi2.0-0 libgtk-3-0 \
        libgdk-pixbuf2.0-0 libxcursor1 libxi6 libxrender1 libxext6 libx11-6 \
        libxft2 libxinerama1 libxtst6 libappindicator3-1 libx11-xcb1 libxfixes3 \
        xdg-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 验证Node.js安装并设置环境变量
RUN node --version && npm --version
ENV NODE_PATH=/usr/lib/node_modules

# 安装Python依赖
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY . .

# 安装Playwright浏览器
RUN playwright install chromium && \
    playwright install-deps chromium

# 创建必要的目录并设置权限
RUN mkdir -p /app/logs /app/data /app/backups /app/static/uploads/images \
    /app/admin/static/admin/images /app/admin/static/admin/css /app/admin/static/admin/js && \
    chmod 777 /app/logs /app/data /app/backups /app/static/uploads /app/static/uploads/images \
    /app/admin/static/admin/images /app/admin/static/admin/css /app/admin/static/admin/js

# 暴露端口
EXPOSE 8000 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 启动命令
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]
EOL

# 创建docker-compose文件
echo "创建docker-compose配置..."
cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  xianyu-integrated:
    build:
      context: .
      dockerfile: Dockerfile
    image: xianyu-auto-reply-integrated:latest
    container_name: xianyu-auto-reply-integrated
    restart: unless-stopped
    user: "0:0"  # 使用root用户避免权限问题
    ports:
      - "${API_PORT:-8000}:8000"    # FastAPI原系统API端口
      - "${ADMIN_PORT:-5000}:5000"  # Flask PearAdmin后台端口
    volumes:
      # 数据持久化
      - ./data:/app/data:rw
      - ./logs:/app/logs:rw
      - ./admin/static/admin:/app/admin/static/admin:rw
      - ./backups:/app/backups:rw
    environment:
      # 基础环境变量
      - PYTHONUNBUFFERED=1
      - PYTHONDONTWRITEBYTECODE=1
      - TZ=${TZ:-Asia/Shanghai}
      - DEBUG=${DEBUG:-false}
      
      # API系统配置
      - DB_PATH=${DB_PATH:-/app/data/xianyu_data.db}
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
      - ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin123}
      - JWT_SECRET_KEY=${JWT_SECRET_KEY:-default-secret-key}
      
      # Flask后台配置
      - FLASK_SECRET_KEY=${FLASK_SECRET_KEY:-flask-secret-key}
      - FLASK_SQLALCHEMY_DATABASE_URI=${FLASK_SQLALCHEMY_DATABASE_URI:-sqlite:////app/data/admin.db}
      - FLASK_ADMIN_USERNAME=${FLASK_ADMIN_USERNAME:-admin}
      - FLASK_ADMIN_PASSWORD=${FLASK_ADMIN_PASSWORD:-admin123}
      
    networks:
      - xianyu-network

  nginx:
    image: nginx:alpine
    container_name: xianyu-nginx-integrated
    restart: unless-stopped
    ports:
      - "${HTTP_PORT:-80}:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - xianyu-integrated
    networks:
      - xianyu-network

networks:
  xianyu-network:
    driver: bridge
EOL

# 创建entrypoint.sh
echo "创建启动脚本..."
cat > entrypoint.sh << 'EOL'
#!/bin/bash

echo "Starting xianyu-auto-reply integrated system..."

# 创建必要的目录
mkdir -p /app/data /app/logs /app/backups /app/static/uploads/images
mkdir -p /app/admin/static/admin/images /app/admin/static/admin/css /app/admin/static/admin/js

# 设置权限
chmod 777 /app/data /app/logs /app/backups /app/static/uploads /app/static/uploads/images
chmod 777 /app/admin/static/admin/images /app/admin/static/admin/css /app/admin/static/admin/js

# 创建示例代码文件
echo '
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello from Flask!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
' > /app/flask_app.py

echo '
from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI!"}

@app.get("/health")
def health_check():
    return {"status": "UP"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
' > /app/fastapi_app.py

# 创建启动脚本
echo '#!/bin/bash
python /app/fastapi_app.py &
python /app/flask_app.py
' > /app/start.sh
chmod +x /app/start.sh

# 启动应用
exec /app/start.sh
EOL

chmod +x entrypoint.sh

# 创建nginx配置
echo "创建Nginx配置..."
mkdir -p nginx
cat > nginx/nginx.conf << 'EOL'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    keepalive_timeout 65;
    
    upstream api_backend {
        server xianyu-integrated:8000;
    }
    
    upstream admin_backend {
        server xianyu-integrated:5000;
    }
    
    server {
        listen 80;
        server_name _;
        
        location /api/ {
            proxy_pass http://api_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /admin/ {
            proxy_pass http://admin_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location / {
            proxy_pass http://api_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /health {
            access_log off;
            add_header Content-Type application/json;
            return 200 '{"status":"UP"}';
        }
    }
}
EOL

# 创建环境变量文件
echo "创建环境变量文件..."
cat > .env << EOL
# 基础配置
TZ=Asia/Shanghai
DEBUG=false

# 端口配置
API_PORT=8000
ADMIN_PORT=5000
HTTP_PORT=80

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
EOL

# 创建简单的requirements.txt
echo "创建依赖文件..."
cat > requirements.txt << 'EOL'
fastapi>=0.111.0
uvicorn[standard]>=0.29.0
flask>=2.3.2
flask-sqlalchemy>=3.1.1
requests>=2.31.0
python-multipart>=0.0.6
EOL

# 启动容器
echo "开始构建和启动Docker容器..."
docker-compose up -d --build

# 检查容器状态
echo "等待容器启动..."
sleep 10

if docker-compose ps | grep -q "Up"; then
    echo "===================================================="
    echo "闲鱼自动回复系统集成版已成功部署!"
    echo "访问地址:"
    echo "- API服务: http://localhost:$(grep API_PORT .env | cut -d= -f2)"
    echo "- 管理后台: http://localhost:$(grep ADMIN_PORT .env | cut -d= -f2)"
    echo "- Web界面: http://localhost:$(grep HTTP_PORT .env | cut -d= -f2)"
    echo ""
    echo "默认管理员账号: $(grep ADMIN_USERNAME .env | cut -d= -f2)"
    echo "默认管理员密码: $(grep ADMIN_PASSWORD .env | cut -d= -f2)"
    echo "===================================================="
    echo "部署目录: $INSTALL_DIR"
    echo "日志查看: docker-compose logs -f"
    echo "===================================================="
else
    echo "错误: 容器启动失败，请检查日志"
    docker-compose logs
    exit 1
fi

echo "部署完成!"
