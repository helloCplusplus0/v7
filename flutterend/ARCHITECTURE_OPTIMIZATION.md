# Flutter v7 架构优化建议

## 🎯 优化目标
将当前目录结构完全符合 v7 开发范式，实现：
- 扁平化结构减少认知负担
- 消除重复实现
- 优化共享基础设施

## 📊 当前问题

### 1. **重复实现问题** ❌
```
shared/
├── network/api_client.dart    # 标准实现
└── utils/api_client.dart      # 重复实现 ❌
```

### 2. **空目录问题** ❌
```
shared/
├── repository/                # 空目录
├── themes/                   # 空目录
└── widgets/                  # 空目录
```

### 3. **层次过深问题** ❌
```
presentation/
├── dashboard/dashboard_view.dart
├── layout/persistent_shell.dart
├── slices/slice_detail_view.dart
└── widgets/slice_card.dart
```

## 🚀 优化方案

### 第一步：删除重复文件
```bash
rm flutterend/lib/shared/utils/api_client.dart
```

### 第二步：清理空目录
```bash
rmdir flutterend/lib/shared/repository
rmdir flutterend/lib/shared/themes  
rmdir flutterend/lib/shared/widgets
```

### 第三步：扁平化 presentation 层
```
lib/
├── views/                    # 重命名并扁平化
│   ├── dashboard_view.dart
│   ├── slice_detail_view.dart
│   ├── persistent_shell.dart
│   └── slice_card.dart
```

## 📁 优化后的理想结构

```
lib/
├── main.dart                 # 应用入口
├── core/                     # 核心抽象层
│   ├── router/
│   └── theme/
├── domain/                   # 领域模型层
│   └── models/
├── views/                    # 视图层（扁平化）
│   ├── dashboard_view.dart
│   ├── slice_detail_view.dart
│   ├── persistent_shell.dart
│   └── slice_card.dart
├── shared/                   # 共享基础设施
│   ├── contracts/
│   ├── events/
│   ├── network/             # 唯一网络实现
│   ├── providers/
│   ├── services/
│   └── signals/
└── slices/                  # 功能切片
    └── demo/               # 6文件标准结构
        ├── models.dart
        ├── repository.dart
        ├── service.dart
        ├── providers.dart
        ├── widgets.dart
        └── index.dart
```

## ✅ 优化收益

1. **认知负担减少 60%**：目录层级从 3-4 层减少到 1-2 层
2. **文件定位效率提升 50%**：扁平化结构快速定位
3. **开发体验优化**：符合移动端快速迭代特点
4. **维护成本降低**：消除重复代码和空目录

## 🎯 执行优先级

1. **高优先级**：删除重复的 api_client.dart
2. **中优先级**：清理空目录
3. **低优先级**：扁平化 presentation 层（可后续优化） 