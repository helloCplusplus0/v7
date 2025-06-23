# 用户管理和权限操作指南

## 🔐 用户权限设计说明

### 用户角色定义

| 用户 | 角色 | 职责 | 权限范围 |
|------|------|------|----------|
| `ubuntu` | 系统管理员 | 系统配置、软件安装、安全管理 | sudo权限、系统级操作 |
| `deploy` | 应用部署员 | 应用部署、容器管理、日志查看 | 应用目录、Podman容器 |

### 为什么不能直接访问

```bash
# ubuntu用户尝试访问deploy目录
ls -la /home/deploy/
# 输出：Permission denied

# 这是Linux安全设计，每个用户只能访问自己的家目录
```

## 🛠️ 正确的操作方式

### 方法1: 切换用户身份（推荐）

```bash
# 从ubuntu切换到deploy
sudo su - deploy

# 验证身份
whoami  # 输出：deploy
pwd     # 输出：/home/deploy

# 现在可以管理应用
cd v7-project
ls -la
```

### 方法2: 使用sudo代理执行

```bash
# 查看应用状态
sudo -u deploy podman ps

# 查看应用日志
sudo -u deploy tail -f /home/deploy/v7-project/logs/backend/app.log

# 重启应用
sudo -u deploy podman-compose -f /home/deploy/v7-project/podman-compose.yml restart

# 进入应用目录
sudo -u deploy bash -c "cd /home/deploy/v7-project && pwd && ls -la"
```

## 📋 常用运维命令

### 应用状态检查

```bash
# 切换到deploy用户后
sudo su - deploy

# 检查容器状态
podman ps -a

# 查看应用日志
tail -f v7-project/logs/backend/app.log
tail -f v7-project/logs/web/access.log

# 检查资源使用
podman stats

# 查看镜像
podman images
```

### 应用部署管理

```bash
# 切换到deploy用户
sudo su - deploy
cd v7-project

# 拉取最新代码（如果需要）
git pull

# 重新构建和部署
podman-compose down
podman-compose up -d --build

# 查看部署状态
podman-compose ps
podman-compose logs -f
```

### 系统级操作（ubuntu用户）

```bash
# 作为ubuntu用户执行
# 系统更新
sudo apt update && sudo apt upgrade

# 安装系统软件
sudo apt install htop iftop

# 配置防火墙
sudo ufw status
sudo ufw allow 8080/tcp

# 查看系统资源
htop
df -h
free -h
```

## 🔄 用户切换快捷操作

### 创建便捷别名

```bash
# 在ubuntu用户的.bashrc中添加
echo "alias to-deploy='sudo su - deploy'" >> ~/.bashrc
echo "alias check-app='sudo -u deploy podman ps'" >> ~/.bashrc
echo "alias app-logs='sudo -u deploy tail -f /home/deploy/v7-project/logs/backend/app.log'" >> ~/.bashrc

# 重新加载配置
source ~/.bashrc

# 现在可以使用
to-deploy      # 快速切换到deploy用户
check-app      # 快速查看应用状态
app-logs       # 快速查看应用日志
```

### 创建管理脚本

```bash
# 创建应用管理脚本
sudo tee /usr/local/bin/app-manage << 'EOF'
#!/bin/bash

case "$1" in
    status)
        sudo -u deploy podman ps
        ;;
    logs)
        sudo -u deploy tail -f /home/deploy/v7-project/logs/backend/app.log
        ;;
    restart)
        sudo -u deploy podman-compose -f /home/deploy/v7-project/podman-compose.yml restart
        ;;
    shell)
        sudo su - deploy
        ;;
    *)
        echo "Usage: $0 {status|logs|restart|shell}"
        exit 1
        ;;
esac
EOF

# 添加执行权限
sudo chmod +x /usr/local/bin/app-manage

# 使用示例
app-manage status   # 查看状态
app-manage logs     # 查看日志
app-manage restart  # 重启应用
app-manage shell    # 切换到deploy用户
```

## 🔍 故障排查

### 权限问题诊断

```bash
# 检查用户身份
whoami
id

# 检查目录权限
ls -la /home/
ls -la /home/deploy/

# 检查sudo权限
sudo -l

# 检查用户组
groups
groups deploy
```

### 常见权限错误解决

```bash
# 错误1：Permission denied
# 解决：使用sudo su - deploy 切换用户

# 错误2：podman: command not found
# 解决：确保在deploy用户环境中执行
sudo su - deploy
which podman

# 错误3：文件权限问题
# 解决：检查文件所有者
ls -la /home/deploy/v7-project/
sudo chown -R deploy:deploy /home/deploy/v7-project/
```

## 📚 最佳实践

### 1. 角色分离原则

- **ubuntu用户**：负责系统级配置和维护
- **deploy用户**：专门负责应用部署和管理
- **避免**：混用用户身份执行不同职责的任务

### 2. 安全操作流程

```bash
# 标准操作流程
1. 使用ubuntu登录系统
2. 执行系统级管理任务
3. 切换到deploy用户：sudo su - deploy
4. 执行应用级管理任务
5. 完成后退出：exit
```

### 3. 权限最小化

- 只给用户必要的权限
- 避免不必要的sudo权限分配
- 定期审查用户权限

## 🚨 安全注意事项

### 不推荐的做法

```bash
# ❌ 不要这样做：给ubuntu用户deploy目录权限
sudo chmod 755 /home/deploy  # 破坏安全隔离

# ❌ 不要这样做：使用root用户管理应用
sudo su -  # 过度权限

# ❌ 不要这样做：修改用户家目录权限
sudo chmod -R 777 /home/deploy  # 严重安全风险
```

### 推荐的做法

```bash
# ✅ 正确做法：角色分离
sudo su - deploy  # 切换到专门的部署用户

# ✅ 正确做法：使用专门的组
sudo usermod -a -G docker deploy  # 给deploy用户必要的组权限

# ✅ 正确做法：使用sudo代理
sudo -u deploy podman ps  # 以deploy身份执行特定命令
```

这种权限设计是Linux系统安全的基石，也是生产环境的标准做法。虽然可能在操作上多一个步骤，但大大提高了系统的安全性和可维护性。 