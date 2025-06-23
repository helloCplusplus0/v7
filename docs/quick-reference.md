# 🚀 V7项目DevOps快速参考

**常用命令和检查清单** - 配合[完整部署指南](./devops-complete-guide.md)使用

---

## 📋 部署前检查清单

### 本地环境准备
```bash
# 1. 检查SSH密钥
ls -la ~/.ssh/
cat ~/.ssh/id_rsa.pub

# 2. 测试服务器连接
ssh deploy@YOUR_SERVER_IP

# 3. 验证GitHub仓库
git remote -v
```

### 服务器环境检查
```bash
# 连接服务器后执行
podman --version
systemctl --user status podman.socket
df -h
free -h
```

---

## 🔧 常用运维命令

### 服务器管理
```bash
# 连接服务器
ssh deploy@YOUR_SERVER_IP

# 查看系统状态
htop
df -h
free -h

# 查看服务状态
systemctl --user status podman.socket
```

### 容器管理
```bash
# 查看运行中的容器
podman ps

# 查看所有容器（包括停止的）
podman ps -a

# 查看容器日志
podman logs v7-backend
podman logs v7-web

# 查看容器资源使用
podman stats

# 重启服务
cd ~/v7-project
podman-compose restart

# 完全重新部署
podman-compose down
podman-compose pull
podman-compose up -d
```

### 健康检查
```bash
# 检查服务健康状态
curl http://localhost:3000/health
curl http://localhost:8080/health

# 检查API功能
curl http://localhost:3000/api/items

# 检查端口监听
netstat -tlnp | grep :3000
netstat -tlnp | grep :8080
```

---

## 🐛 故障排除命令

### 常见问题诊断
```bash
# 1. 容器无法启动
podman logs v7-backend --tail 50
podman logs v7-web --tail 50

# 2. 端口被占用
sudo netstat -tlnp | grep :3000
sudo netstat -tlnp | grep :8080

# 3. 磁盘空间不足
df -h
du -sh ~/v7-project/*

# 4. 内存不足
free -h
podman stats --no-stream

# 5. 镜像拉取失败
podman pull ghcr.io/hellocplusplus0/v7/backend:latest
podman pull ghcr.io/hellocplusplus0/v7/web:latest
```

### 服务重置
```bash
# 完全重置服务（谨慎使用）
cd ~/v7-project
podman-compose down
podman system prune -a -f
podman-compose up -d
```

---

## 📊 监控命令

### 实时监控
```bash
# 系统资源监控
htop

# 容器资源监控
watch -n 2 'podman stats --no-stream'

# 磁盘使用监控
watch -n 5 'df -h'

# 服务日志监控
podman logs -f v7-backend
podman logs -f v7-web
```

### 自动化监控脚本
```bash
# 使用项目提供的监控脚本
cd ~/v7-project
./scripts/monitoring.sh

# 持续监控模式
./scripts/monitoring.sh --continuous
```

---

## 🔄 部署相关

### 手动部署
```bash
# 在服务器上手动更新
cd ~/v7-project
git pull
podman-compose down
podman-compose pull
podman-compose up -d
```

### 回滚部署
```bash
# 快速回滚到稳定版本
cd ~/v7-project
podman-compose down
podman pull ghcr.io/hellocplusplus0/v7/backend:stable
podman pull ghcr.io/hellocplusplus0/v7/web:stable
podman-compose up -d
```

### 查看部署历史
```bash
# 查看镜像历史
podman images | grep v7

# 查看容器创建时间
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
```

---

## 🌐 GitHub Actions相关

### 检查部署状态
1. 访问GitHub仓库的Actions页面
2. 查看最新workflow运行状态
3. 如果失败，点击查看详细日志

### 触发手动部署
```bash
# 在本地项目目录
git add .
git commit -m "feat: 手动触发部署"
git push github main
```

### GitHub Secrets检查
确保以下Secrets已正确配置：
- `SERVER_HOST`
- `SERVER_USER` 
- `SERVER_SSH_KEY`
- `DEPLOY_PATH`
- `BACKEND_IMAGE`
- `WEB_IMAGE`

---

## 📱 移动端快速检查

### 一键健康检查脚本
```bash
#!/bin/bash
# 保存为 check-health.sh
echo "🔍 V7服务健康检查"
echo "===================="

# 检查容器状态
echo "📦 容器状态:"
podman ps --format "table {{.Names}}\t{{.Status}}"

# 检查服务健康
echo -e "\n🏥 服务健康:"
curl -s http://localhost:3000/health && echo " ✅ 后端健康" || echo " ❌ 后端异常"
curl -s http://localhost:8080/health && echo " ✅ 前端健康" || echo " ❌ 前端异常"

# 检查资源使用
echo -e "\n📊 资源使用:"
podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo -e "\n💾 磁盘使用:"
df -h ~/v7-project
```

使用方法：
```bash
chmod +x check-health.sh
./check-health.sh
```

---

## 🆘 紧急情况处理

### 服务完全无响应
```bash
# 1. 检查服务器连接
ping YOUR_SERVER_IP

# 2. SSH连接服务器
ssh deploy@YOUR_SERVER_IP

# 3. 检查系统状态
systemctl status
df -h
free -h

# 4. 重启所有服务
cd ~/v7-project
podman-compose down
podman-compose up -d

# 5. 如果仍有问题，重启服务器
sudo reboot
```

### 数据备份
```bash
# 备份数据库
cp ~/v7-project/data/prod.db ~/v7-project/data/prod.db.backup.$(date +%Y%m%d_%H%M%S)

# 备份日志
tar -czf ~/v7-project/logs-backup-$(date +%Y%m%d_%H%M%S).tar.gz ~/v7-project/logs/
```

---

## 📞 获取帮助

### 查看详细文档
- [完整部署指南](./devops-complete-guide.md) - 详细的步骤说明
- [项目README](../README.md) - 项目概览

### 常用资源
- [Podman官方文档](https://podman.io/docs)
- [GitHub Actions文档](https://docs.github.com/actions)
- [项目Issues](https://github.com/helloCplusplus0/v7/issues) - 报告问题

### 日志文件位置
```bash
# 应用日志
~/v7-project/logs/backend/
~/v7-project/logs/web/

# 系统日志
journalctl --user -u podman
```

---

**💡 提示**: 建议将常用命令保存为shell别名或脚本，提高运维效率。 