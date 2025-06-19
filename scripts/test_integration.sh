#!/bin/bash

echo "🧪 开始 hello_fmod 切片集成测试..."

# 测试后端API
echo "📡 测试后端API..."

# 测试GET端点
echo "1. 测试 GET /api/hello"
RESPONSE=$(curl -s http://localhost:3000/api/hello)
if echo "$RESPONSE" | grep -q "Hello fmod!"; then
    echo "✅ GET /api/hello 测试通过"
else
    echo "❌ GET /api/hello 测试失败: $RESPONSE"
    exit 1
fi

# 测试POST端点
echo "2. 测试 POST /api/hello"
RESPONSE=$(curl -s -X POST http://localhost:3000/api/hello \
    -H "Content-Type: application/json" \
    -d '{"message":"Integration test"}')
if echo "$RESPONSE" | grep -q "Echo: Integration test"; then
    echo "✅ POST /api/hello 测试通过"
else
    echo "❌ POST /api/hello 测试失败: $RESPONSE"
    exit 1
fi

# 测试前端
echo "📱 测试前端..."

# 检查前端页面是否可访问
echo "3. 测试前端页面加载"
if curl -s http://localhost:5173 | grep -q "FMOD Web Application"; then
    echo "✅ 前端页面加载测试通过"
else
    echo "❌ 前端页面加载测试失败"
    exit 1
fi

echo ""
echo "🎉 所有测试通过！hello_fmod 切片前后端联调成功！"
echo ""
echo "📋 测试摘要："
echo "   ✅ 后端 Axum 服务器运行正常 (http://localhost:3000)"
echo "   ✅ GET /api/hello 返回正确响应"
echo "   ✅ POST /api/hello 处理自定义消息"
echo "   ✅ 前端 Vite 开发服务器运行正常 (http://localhost:5173)"
echo "   ✅ 前端页面正常加载"
echo ""
echo "🌐 访问地址："
echo "   前端: http://localhost:5173"
echo "   后端: http://localhost:3000"
echo "   API文档: http://localhost:3000/api/hello" 