#!/bin/bash

echo "Starting xianyu-auto-reply integrated system..."

# 创建必要的目录
mkdir -p /app/data /app/logs /app/backups /app/static/uploads/images
mkdir -p /app/admin/static/admin/images /app/admin/static/admin/css /app/admin/static/admin/js

# 设置权限
chmod 777 /app/data /app/logs /app/backups /app/static/uploads /app/static/uploads/images
chmod 777 /app/admin/static/admin/images /app/admin/static/admin/css /app/admin/static/admin/js

# 初始化数据库
echo "Initializing databases..."
python -c "
from admin.applications.extensions import db
from admin.applications.models.admin_user import User
from admin.app import app as flask_app

with flask_app.app_context():
    # 创建表
    db.create_all()
    
    # 检查是否已存在管理员账户
    admin = User.query.filter_by(username='admin').first()
    if not admin:
        # 创建默认管理员账户
        admin = User(username='admin', real_name='系统管理员', email='admin@example.com')
        admin.password = 'admin123'  # 密码会自动哈希
        admin.is_admin = True
        db.session.add(admin)
        db.session.commit()
        print('已创建默认管理员账户: admin/admin123')
    else:
        print('管理员账户已存在')
"

# 启动集成系统
echo "Starting integrated system with FastAPI and Flask..."
exec python main.py
