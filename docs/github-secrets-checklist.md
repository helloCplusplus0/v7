# 🔑 GitHub Secrets 配置清单

> **基于您当前服务器配置的最终确认清单**

## 📋 必需配置的Secrets

在GitHub仓库的 **Settings → Secrets and variables → Actions** 中添加以下Secrets：

### 🌐 服务器连接配置

| Secret名称 | 值 | 说明 |
|-----------|----|----|
| `SERVER_HOST` | `43.134.119.134` | 您的轻量级云服务器IP |
| `SERVER_USER` | `deploy` | 部署用户（已创建并配置） |
| `SERVER_PORT` | `22` | SSH端口 |
| `SERVER_SSH_KEY` | `[私钥内容]` | 完整的RSA私钥内容 |

### 📁 部署路径配置

| Secret名称 | 值 | 说明 |
|-----------|----|----|
| `DEPLOY_PATH` | `/home/deploy/containers/v7-project` | 推荐的统一部署目录 |

### 🐳 镜像配置

| Secret名称 | 值 | 说明 |
|-----------|----|----|
| `BACKEND_IMAGE` | `ghcr.io/hellocplusplus0/v7/backend` | 后端镜像地址 |
| `WEB_IMAGE` | `ghcr.io/hellocplusplus0/v7/web` | 前端镜像地址 |

### 🔧 环境变量配置

| Secret名称 | 值 | 说明 |
|-----------|----|----|
| `DATABASE_URL` | `sqlite:./data/prod.db` | 数据库连接地址 |
| `RUST_LOG` | `info` | 后端日志级别 |
| `NODE_ENV` | `production` | 前端环境模式 |

## 🔐 SERVER_SSH_KEY 内容格式

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA2+eGVG6N8Fzrpkj5Qj8FyQ9mZD8QRFr...
（这里是完整的私钥内容，包括所有换行）
...
-----END RSA PRIVATE KEY-----
```

**⚠️ 重要提醒**：
- 复制私钥时必须包含 `-----BEGIN RSA PRIVATE KEY-----` 和 `-----END RSA PRIVATE KEY-----` 行
- 保持原有的换行格式
- 不要添加任何额外的空格或字符

## 🎯 配置验证

配置完成后，您可以通过以下方式验证：

### 1. 推送代码触发CI/CD
```bash
git add .
git commit -m "feat: trigger CI/CD pipeline"
git push -u github main
```

### 2. 查看GitHub Actions执行
- 前往 GitHub 仓库的 **Actions** 标签页
- 查看最新的工作流执行状态
- 检查每个步骤的日志输出

### 3. 验证部署结果
- 前端访问：`http://43.134.119.134:8080`
- 后端API：`http://43.134.119.134:3000`
- 健康检查：`http://43.134.119.134:3000/health`

## 🔄 目录结构优化建议

为了更好的项目管理，建议在服务器上执行：

```bash
# 创建统一的容器目录
sudo -u deploy mkdir -p /home/deploy/containers

# 移动现有项目到新目录结构
sudo -u deploy mv /home/deploy/v7-project /home/deploy/containers/

# 更新部署路径（在GitHub Secrets中）
# DEPLOY_PATH: /home/deploy/containers/v7-project
```

## 🚀 首次部署流程

1. **配置GitHub Secrets**（使用上述清单）
2. **提交代码变更**（触发CI/CD）
3. **等待自动部署**（约3-5分钟）
4. **验证部署结果**（访问服务地址）

## 🛠️ 故障排除

如果部署失败，请检查：

1. **SSH连接**：GitHub Actions能否连接到服务器
2. **权限问题**：deploy用户是否有足够权限
3. **服务状态**：Podman服务是否正常运行
4. **端口冲突**：3000和8080端口是否被占用

---

**完成此配置后，您将拥有一个完全自动化的CI/CD部署流程！** 