# 🚀 V7项目完整DevOps部署指南

**从零到生产的完整自动化部署流程** - 支持单服务器到多服务器扩展

---

## 📋 部署架构概览

### 阶段一：单服务器部署（当前）
```
GitHub Repository
       ↓ (git push)
GitHub Actions CI/CD
       ↓ (docker build & push)
GitHub Container Registry (GHCR)
       ↓ (SSH deployment)
轻量级云服务器 (2核2G)
├── Podman Runtime
├── v7-backend (1核512M)
├── v7-web (0.5核256M)
└── 监控服务 (0.1核64M)
```

### 阶段二：多服务器扩展（未来）
```
GitHub Repository
       ↓
GitHub Actions CI/CD
       ↓
GHCR (镜像仓库)
       ↓
负载均衡器
├── 服务器1 (生产环境)
├── 服务器2 (测试环境)
└── 服务器3 (备份/扩展)
```

---

## 🎯 第一阶段：单服务器部署（必须按顺序执行）

### 步骤1：云服务器购买和基础配置

#### 1.1 服务器规格要求
- **最低配置**: 2核2G内存，20GB存储
- **推荐配置**: 2核4G内存，40GB存储
- **操作系统**: Ubuntu 22.04 LTS 或 CentOS 8+

#### 1.2 获取服务器信息
```bash
# 记录以下信息，后续配置需要：
SERVER_IP=你的服务器IP        # 例如：192.168.31.84
SERVER_USER=root             # 或者你的用户名
SSH_PORT=22                  # 默认22，如果修改过请记录实际端口
```

### 步骤2：本地SSH密钥准备

#### 2.1 生成SSH密钥（如果没有）
```bash
# 在本地机器执行
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
# 密钥路径：~/.ssh/id_rsa (私钥) 和 ~/.ssh/id_rsa.pub (公钥)
```

#### 2.2 复制公钥到服务器
```bash
# 方法1：使用ssh-copy-id（推荐）
ssh-copy-id -p $SSH_PORT $SERVER_USER@$SERVER_IP

# 方法2：手动复制
cat ~/.ssh/id_rsa.pub
# 然后登录服务器，将内容添加到 ~/.ssh/authorized_keys
```

#### 2.3 测试SSH连接
```bash
ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP
# 应该能免密码登录
```

### 步骤3：服务器环境准备

#### 3.1 连接到服务器
```bash
ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP
```

#### 3.2 系统更新
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

#### 3.3 安装基础工具
```bash
# Ubuntu/Debian
sudo apt install -y curl wget git unzip htop

# CentOS/RHEL
sudo yum install -y curl wget git unzip htop
```

#### 3.4 安装Podman
```bash
# Ubuntu 22.04
sudo apt update
sudo apt install -y podman podman-compose

# CentOS 8+
sudo dnf install -y podman podman-compose

# 验证安装
podman --version
podman-compose --version
```

#### 3.5 创建部署用户（安全最佳实践）
```bash
# 创建专用部署用户
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG wheel deploy  # CentOS
sudo usermod -aG sudo deploy   # Ubuntu

# 设置密码（可选，推荐使用SSH密钥）
sudo passwd deploy

# 为deploy用户设置SSH密钥
sudo mkdir -p /home/deploy/.ssh
sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys

# 测试deploy用户登录
exit
ssh -p $SSH_PORT deploy@$SERVER_IP
```

#### 3.6 配置Podman用户权限
```bash
# 以deploy用户身份执行
# 启用用户级systemd服务
systemctl --user enable podman.socket
loginctl enable-linger deploy

# 测试Podman
podman run hello-world
```

#### 3.7 创建项目目录结构
```bash
# 以deploy用户身份执行
mkdir -p ~/v7-project/{data,logs/{backend,web},scripts}
cd ~/v7-project

# 设置权限
chmod 755 ~/v7-project
chmod 755 ~/v7-project/data
chmod 755 ~/v7-project/logs
```

### 步骤4：GitHub仓库配置

#### 4.1 GitHub Secrets设置
在GitHub仓库中设置以下Secrets（Settings → Secrets and variables → Actions）：

**必需的Secrets：**
```bash
# 服务器连接信息
SERVER_HOST=你的服务器IP
SERVER_USER=deploy
SERVER_SSH_KEY=你的私钥内容（~/.ssh/id_rsa的完整内容）
SERVER_PORT=22

# 部署路径
DEPLOY_PATH=/home/deploy/v7-project

# 镜像配置
BACKEND_IMAGE=ghcr.io/hellocplusplus0/v7/backend
WEB_IMAGE=ghcr.io/hellocplusplus0/v7/web

# 环境变量
DATABASE_URL=sqlite:./data/prod.db
RUST_LOG=info
NODE_ENV=production
```

#### 4.2 获取私钥内容
```bash
# 在本地机器执行
cat ~/.ssh/id_rsa
# 复制完整输出（包括-----BEGIN和-----END行）到SERVER_SSH_KEY
```

### 步骤5：首次部署

#### 5.1 推送代码触发部署
```bash
# 在本地项目目录
git add .
git commit -m "feat: 配置生产环境部署"
git push github main
```

#### 5.2 监控部署过程
1. 访问GitHub仓库的Actions页面
2. 查看最新的workflow运行状态
3. 如果失败，查看日志解决问题

#### 5.3 验证部署结果
```bash
# 在服务器上检查服务状态
ssh deploy@$SERVER_IP
cd ~/v7-project

# 查看容器状态
podman ps -a

# 查看服务日志
podman logs v7-backend
podman logs v7-web

# 测试服务
curl http://localhost:3000/health  # 后端健康检查
curl http://localhost:8080/health  # 前端健康检查
```

#### 5.4 配置防火墙（如果需要）
```bash
# Ubuntu UFW
sudo ufw allow 22    # SSH
sudo ufw allow 3000  # 后端API
sudo ufw allow 8080  # 前端Web
sudo ufw enable

# CentOS firewalld
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### 步骤6：验证完整系统

#### 6.1 功能测试
```bash
# 访问前端应用
curl -I http://$SERVER_IP:8080

# 测试API
curl http://$SERVER_IP:3000/api/items

# 测试CRUD功能
curl -X POST http://$SERVER_IP:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":100}'
```

#### 6.2 性能监控
```bash
# 查看系统资源使用
htop

# 查看容器资源使用
podman stats

# 查看磁盘使用
df -h
```

---

## 🎯 第二阶段：多服务器扩展方案

### 扩展场景规划

#### 场景A：测试环境分离
```
服务器1: 生产环境 (main分支)
服务器2: 测试环境 (develop分支)
```

#### 场景B：负载均衡扩展
```
负载均衡器 (Nginx/HAProxy)
├── 服务器1: 主要应用实例
├── 服务器2: 备份应用实例
└── 服务器3: 数据库/缓存服务
```

#### 场景C：微服务分离
```
服务器1: 前端Web服务
服务器2: 后端API服务
服务器3: 数据库和缓存
```

### 多服务器部署配置

#### 2.1 GitHub Actions环境配置

修改`.github/workflows/ci-cd.yml`以支持多环境：

```yaml
name: V7 Multi-Environment CI/CD

on:
  push:
    branches: [ main, develop, staging ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: 
          - name: production
            branch: main
            server: ${{ secrets.PROD_SERVER_HOST }}
            user: ${{ secrets.PROD_SERVER_USER }}
            ssh_key: ${{ secrets.PROD_SSH_KEY }}
            deploy_path: ${{ secrets.PROD_DEPLOY_PATH }}
          - name: staging
            branch: develop
            server: ${{ secrets.STAGING_SERVER_HOST }}
            user: ${{ secrets.STAGING_SERVER_USER }}
            ssh_key: ${{ secrets.STAGING_SSH_KEY }}
            deploy_path: ${{ secrets.STAGING_DEPLOY_PATH }}
    
    steps:
      - name: Deploy to ${{ matrix.environment.name }}
        if: github.ref == format('refs/heads/{0}', matrix.environment.branch)
        # 部署逻辑...
```

#### 2.2 新增GitHub Secrets

为每个环境添加独立的Secrets：

**生产环境 (PROD_*)：**
```
PROD_SERVER_HOST=生产服务器IP
PROD_SERVER_USER=deploy
PROD_SSH_KEY=生产服务器私钥
PROD_DEPLOY_PATH=/home/deploy/v7-production
```

**测试环境 (STAGING_*)：**
```
STAGING_SERVER_HOST=测试服务器IP
STAGING_SERVER_USER=deploy
STAGING_SSH_KEY=测试服务器私钥
STAGING_DEPLOY_PATH=/home/deploy/v7-staging
```

#### 2.3 新服务器准备流程

**为每台新服务器重复步骤2-3：**

1. 配置SSH密钥访问
2. 安装Podman和基础工具
3. 创建deploy用户
4. 创建项目目录
5. 配置防火墙

#### 2.4 负载均衡配置（可选）

如果需要负载均衡，在前端添加Nginx：

```nginx
# /etc/nginx/conf.d/v7-lb.conf
upstream v7_backend {
    server 服务器1_IP:3000;
    server 服务器2_IP:3000;
}

upstream v7_frontend {
    server 服务器1_IP:8080;
    server 服务器2_IP:8080;
}

server {
    listen 80;
    server_name your-domain.com;

    location /api/ {
        proxy_pass http://v7_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        proxy_pass http://v7_frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 🔧 运维管理工具

### 统一部署脚本

创建`scripts/multi-deploy.sh`：

```bash
#!/bin/bash
# 多服务器部署管理脚本

ENVIRONMENTS=("production" "staging" "development")
SERVERS=("prod-server-ip" "staging-server-ip" "dev-server-ip")

deploy_to_environment() {
    local env=$1
    local server=$2
    
    echo "🚀 部署到 $env 环境 ($server)"
    
    ssh deploy@$server << 'EOF'
        cd ~/v7-project
        git pull
        podman-compose down
        podman-compose pull
        podman-compose up -d
        echo "✅ $env 环境部署完成"
EOF
}

# 主函数
main() {
    case $1 in
        "all")
            for i in "${!ENVIRONMENTS[@]}"; do
                deploy_to_environment "${ENVIRONMENTS[$i]}" "${SERVERS[$i]}"
            done
            ;;
        "production"|"staging"|"development")
            # 部署到指定环境
            ;;
        *)
            echo "用法: $0 {all|production|staging|development}"
            exit 1
            ;;
    esac
}

main "$@"
```

### 监控脚本增强

修改`scripts/monitoring.sh`支持多服务器：

```bash
#!/bin/bash
# 多服务器监控脚本

SERVERS=("prod:prod-ip" "staging:staging-ip")

monitor_server() {
    local name=$1
    local ip=$2
    
    echo "📊 监控服务器: $name ($ip)"
    
    # 检查服务器连通性
    if ! ping -c 1 $ip > /dev/null 2>&1; then
        echo "❌ $name 服务器不可达"
        return 1
    fi
    
    # 检查服务状态
    ssh deploy@$ip << 'EOF'
        echo "🔍 容器状态:"
        podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        echo -e "\n📈 资源使用:"
        podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        
        echo -e "\n💾 磁盘使用:"
        df -h /home/deploy/v7-project
EOF
}

# 监控所有服务器
for server_info in "${SERVERS[@]}"; do
    IFS=':' read -r name ip <<< "$server_info"
    monitor_server "$name" "$ip"
    echo "----------------------------------------"
done
```

---

## 📋 故障排除指南

### 常见问题解决

#### 问题1：SSH连接失败
```bash
# 检查SSH服务
sudo systemctl status ssh

# 检查防火墙
sudo ufw status
sudo firewall-cmd --list-all

# 测试SSH连接
ssh -v deploy@$SERVER_IP
```

#### 问题2：Podman权限问题
```bash
# 检查用户组
groups deploy

# 重新配置用户权限
sudo usermod -aG wheel deploy
loginctl enable-linger deploy
```

#### 问题3：容器启动失败
```bash
# 查看详细日志
podman logs v7-backend --tail 50
podman logs v7-web --tail 50

# 检查镜像
podman images

# 检查端口占用
netstat -tlnp | grep :3000
netstat -tlnp | grep :8080
```

#### 问题4：GitHub Actions部署失败
1. 检查Secrets配置是否正确
2. 验证SSH密钥格式
3. 检查服务器磁盘空间
4. 查看Actions日志

### 回滚策略

```bash
#!/bin/bash
# 快速回滚脚本
rollback_deployment() {
    echo "🔄 开始回滚..."
    
    # 停止当前服务
    podman-compose down
    
    # 拉取上一个稳定版本
    podman pull ghcr.io/hellocplusplus0/v7/backend:stable
    podman pull ghcr.io/hellocplusplus0/v7/web:stable
    
    # 重新启动服务
    podman-compose up -d
    
    echo "✅ 回滚完成"
}
```

---

## 📊 部署检查清单

### 首次部署检查
- [ ] 服务器基础环境配置完成
- [ ] SSH密钥配置正确
- [ ] Podman安装和配置完成
- [ ] 部署用户创建和权限设置
- [ ] GitHub Secrets配置完成
- [ ] 防火墙规则配置
- [ ] 首次部署成功
- [ ] 健康检查通过
- [ ] 功能测试完成

### 扩展部署检查
- [ ] 新服务器环境准备
- [ ] 多环境GitHub Actions配置
- [ ] 新环境Secrets配置
- [ ] 负载均衡配置（如需要）
- [ ] 监控脚本更新
- [ ] 故障转移测试
- [ ] 性能测试完成

---

## 🎯 总结

通过这个完整的DevOps指南，您可以：

1. **第一阶段**：在单台轻量级服务器上完成完整的自动化部署
2. **第二阶段**：无缝扩展到多服务器架构
3. **持续运维**：使用提供的监控和管理工具

每个步骤都有明确的先后顺序和验证方法，确保部署过程可靠、可重复。当您需要扩展到第二台、第三台服务器时，只需要按照第二阶段的指南进行配置即可。 