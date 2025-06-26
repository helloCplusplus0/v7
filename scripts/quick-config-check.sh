#!/bin/bash

# 🔍 快速配置一致性检查
echo "🔍 V7项目快速配置检查"
echo "====================="

# 检查用户ID一致性
echo "1. 检查用户ID配置..."

BACKEND_UID=$(grep -o "adduser -u [0-9]*" backend/Dockerfile 2>/dev/null | grep -o "[0-9]*" || echo "未找到")
WEB_UID=$(grep -o "adduser -u [0-9]*" web/Dockerfile 2>/dev/null | grep -o "[0-9]*" || echo "未找到") 
COMPOSE_UID=$(grep -o 'user: "[0-9]*:[0-9]*"' podman-compose.yml 2>/dev/null | grep -o "[0-9]*" | head -1 || echo "未找到")

echo "   后端Dockerfile用户ID: $BACKEND_UID"
echo "   前端Dockerfile用户ID: $WEB_UID"
echo "   Compose文件用户ID: $COMPOSE_UID"

if [[ "$BACKEND_UID" == "1002" && "$WEB_UID" == "1002" && "$COMPOSE_UID" == "1002" ]]; then
    echo "   ✅ 用户ID配置一致"
    USER_CONFIG_OK=true
else
    echo "   ❌ 用户ID配置不一致"
    USER_CONFIG_OK=false
fi

# 检查数据库配置
echo ""
echo "2. 检查数据库配置..."
if [[ -f ".env.production" ]]; then
    if grep -q "DATABASE_URL=sqlite:/app/data/prod.db" .env.production; then
        echo "   ✅ 数据库路径配置正确"
        DB_CONFIG_OK=true
    else
        echo "   ❌ 数据库路径配置错误"
        DB_CONFIG_OK=false
    fi
else
    echo "   ❌ .env.production文件不存在"
    DB_CONFIG_OK=false
fi

# 检查CI/CD关键特性
echo ""
echo "3. 检查CI/CD关键特性..."
if [[ -f ".github/workflows/ci-cd.yml" ]]; then
    FEATURES_OK=0
    
    if grep -q "验证输出不为空" .github/workflows/ci-cd.yml; then
        echo "   ✅ 镜像标签防空逻辑"
        FEATURES_OK=$((FEATURES_OK + 1))
    fi
    
    if grep -q "Comprehensive Authentication Check" .github/workflows/ci-cd.yml; then
        echo "   ✅ 全面认证检查"
        FEATURES_OK=$((FEATURES_OK + 1))
    fi
    
    if grep -q "备用方法计算小写用户名" .github/workflows/ci-cd.yml; then
        echo "   ✅ 备用逻辑"
        FEATURES_OK=$((FEATURES_OK + 1))
    fi
    
    if [[ $FEATURES_OK -eq 3 ]]; then
        echo "   ✅ CI/CD关键特性完整"
        CICD_CONFIG_OK=true
    else
        echo "   ⚠️ CI/CD特性不完整 ($FEATURES_OK/3)"
        CICD_CONFIG_OK=false
    fi
else
    echo "   ❌ CI/CD配置文件不存在"
    CICD_CONFIG_OK=false
fi

# 总结
echo ""
echo "📊 配置状态总结"
echo "================"

if [[ "$USER_CONFIG_OK" == true && "$DB_CONFIG_OK" == true && "$CICD_CONFIG_OK" == true ]]; then
    echo "🎉 所有关键配置正确！"
    echo ""
    echo "✅ 建议操作："
    echo "   1. 提交代码变更触发新镜像构建"
    echo "   2. 等待CI/CD自动部署"
    echo "   3. 保持现有CI/CD配置不变"
    exit 0
else
    echo "⚠️ 存在配置问题需要修复"
    exit 1
fi 