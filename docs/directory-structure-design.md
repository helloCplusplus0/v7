# 🗂️ 部署目录结构设计说明

## 🎯 设计原则

### ✅ 推荐方案：统一部署目录
```bash
/home/deploy/
├── containers/           # 容器部署统一目录
│   ├── v7-project/       # 当前项目
│   │   ├── data/
│   │   ├── logs/
│   │   └── podman-compose.yml
│   ├── future-project-1/ # 未来项目1
│   │   ├── data/
│   │   ├── logs/
│   │   └── docker-compose.yml
│   └── future-project-2/ # 未来项目2
├── shared/               # 共享资源
│   ├── nginx/           # 反向代理配置
│   ├── monitoring/      # 监控配置
│   └── backups/         # 备份存储
└── scripts/             # 通用脚本
    ├── deploy-common.sh
    ├── backup.sh
    └── monitoring.sh
```

### ❌ 避免方案：分散目录
```bash
/opt/v7-project/          # 项目1散落在/opt
/home/deploy/my-app/      # 项目2散落在/home
/var/www/another-app/     # 项目3散落在/var
```

## 🎯 设计优势

### 1. 统一管理
- **集中部署**: 所有容器项目在一个父目录下
- **权限统一**: deploy用户对整个containers目录有完整权限
- **备份简化**: 只需备份一个containers目录

### 2. 运维效率
- **脚本复用**: 通用脚本可以服务多个项目
- **监控统一**: 一套监控系统覆盖所有项目
- **日志集中**: 所有项目日志在统一位置

### 3. 扩展性
- **新项目**: 只需在containers下创建新子目录
- **资源共享**: nginx、监控等可以跨项目共享
- **团队协作**: 其他开发者容易理解目录结构

## 🔧 实际配置建议

### GitHub Secrets配置
```bash
# 基础部署路径
DEPLOY_BASE_PATH=/home/deploy/containers

# 项目特定路径（自动计算）
DEPLOY_PATH=${DEPLOY_BASE_PATH}/v7-project
```

### 脚本自动处理
```bash
#!/bin/bash
# 部署脚本自动创建项目目录
PROJECT_NAME="v7-project"
BASE_PATH="/home/deploy/containers"
PROJECT_PATH="${BASE_PATH}/${PROJECT_NAME}"

# 自动创建项目专属目录
mkdir -p "${PROJECT_PATH}"/{data,logs,config}
cd "${PROJECT_PATH}"
```

## 🚀 迁移建议

如果要从现有方案迁移到统一目录：

1. **创建新目录结构**
```bash
sudo mkdir -p /home/deploy/containers
sudo chown -R deploy:deploy /home/deploy/containers
```

2. **迁移现有项目**
```bash
mv /home/deploy/v7-project /home/deploy/containers/
```

3. **更新GitHub Secrets**
```bash
DEPLOY_PATH=/home/deploy/containers/v7-project
```

这样设计既保持了你的理解（统一部署目录），又为未来扩展留下了空间。 