# Flutter 2025 Latest Best Practices Standard Prompt (v2.0)

## 🚀 Real-time Update Mechanism

**CRITICAL REQUIREMENT**: Before initiating any Flutter development task, you MUST execute the following steps:

```
Step 1: Search for Latest Flutter Version and Features
- Query: "Flutter 2025 latest version features"
- Query: "Flutter [current latest version] release notes"

Step 2: Confirm Latest Design Standards
- Query: "Material 3 Expressive Flutter 2025"
- Query: "Flutter adaptive design best practices 2025"

Step 3: Retrieve Latest Best Practices
- Query: "Flutter best practices 2025 performance"
- Query: "Flutter architecture recommendations 2025"

Development work can ONLY commence after obtaining the latest information.
```

## 📋 2025 Flutter Latest Standard Requirements

### 1. Modern Flutter Features Mandatory Requirements
Based on latest search information, MUST use:

- **Flutter 3.32+**: Utilize latest Flutter 3.32 version features, including null-aware elements and formatting improvements
- **Dart 3.8+**: Support null-aware elements syntax simplification and trailing comma preservation options
- **Material 3 Expressive**: MUST adopt Material 3 Expressive design system, focusing on latest design iterations
- **Complete Null Safety**: Remove all null-unsafe code, mandatory null safety enablement

### 2. 2025 Navigation Best Practices
- **GoRouter Priority**: Use GoRouter as the preferred navigation solution, supporting deep linking and declarative routing
- **Centralized Route Management**: Maintain all routes in a single file or dedicated routing class
- **GoRouter 8.0+ Features**: Understand the difference between Go vs Push, web URL behavior changes

### 3. 2025 State Management Strategy
- **Hybrid Strategy**: Use local state for temporary UI interactions, structured frameworks for business logic
- **Immutability Principle**: Immutability is now a widely accepted best practice for Flutter applications
- **Recommended Solutions**: 2025 recommends starting with simple solutions like Riverpod or GetX

### 4. Performance and Architecture Requirements
- **UI and Data Layer Separation**: MUST separate UI layer and data layer, further separate logic into classes by responsibility
- **Constraint Layout Understanding**: Master Flutter's golden layout rule: constraints go down, sizes go up, parent sets position
- **Adaptive Design**: Support basic mouse, trackpad, and keyboard shortcuts, implement accessibility keyboard navigation

## 💎 High-Quality Code Standards (9.6 Score Target)

### 1. Upgraded Coding Standards
```dart
// ✅ 2025 Standard Example
class UserRepository {
  // Use null-aware elements (Dart 3.8+)
  List<User> get users => _users.whereType<User>().toList();
  
  // Mandatory const constructors and final fields
  const UserRepository({required this.apiService});
  final ApiService apiService;
  
  // Async operations must handle all exception types
  Future<Result<User>> getUser(String id) async {
    try {
      final response = await apiService.fetchUser(id);
      return Success(User.fromJson(response.data));
    } on NetworkException catch (e) {
      return Failure(NetworkError(e.message));
    } on ValidationException catch (e) {
      return Failure(ValidationError(e.message));
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }
}
```

### 2. Material 3 Expressive UI Standards
```dart
// ✅ MUST use Material 3 Expressive
class ModernAppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive, // 2025 new feature
    ),
    // Use latest Material 3 components
    cardTheme: const CardTheme(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
```

### 3. GoRouter Centralized Configuration Standards
```dart
// ✅ 2025 Routing Best Practices
final appRouter = GoRouter(
  // Centralized route definitions
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: '/user/:id',
          builder: (context, state) {
            final userId = state.pathParameters['id']!;
            return UserDetailScreen(userId: userId);
          },
        ),
      ],
    ),
  ],
  // Error handling
  errorBuilder: (context, state) => ErrorScreen(error: state.error),
  // Redirect logic
  redirect: (context, state) {
    // Authentication checks and other logic
    return null;
  },
);
```

### 4. Modern State Management Patterns
```dart
// ✅ Riverpod 2025 Best Practices
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  AsyncValue<User?> build() {
    return const AsyncValue.data(null);
  }
  
  // Immutable state updates
  Future<void> updateUser(User user) async {
    state = const AsyncValue.loading();
    try {
      final updatedUser = await ref.read(userRepositoryProvider).updateUser(user);
      state = AsyncValue.data(updatedUser);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
```

### 5. Advanced Performance Optimization Requirements
```dart
// ✅ 2025 Performance Optimization Standards
class OptimizedListView extends StatelessWidget {
  const OptimizedListView({super.key, required this.items});
  final List<Item> items;
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListView.builder(
        // Mandatory use of builder pattern
        itemCount: items.length,
        // Height estimation optimization
        prototypeItem: items.isNotEmpty ? ItemTile(item: items.first) : null,
        // Cache extent optimization
        cacheExtent: 500.0,
        itemBuilder: (context, index) {
          final item = items[index];
          return RepaintBoundary(
            key: ValueKey(item.id),
            child: ItemTile(item: item),
          );
        },
      ),
    );
  }
}
```

### 6. Enhanced Security and Testing Standards
```dart
// ✅ Secure Storage Best Practices
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainItemAccessibility.first_unlock_this_device,
    ),
  );
  
  Future<void> storeToken(String token) async {
    await _storage.write(
      key: 'auth_token',
      value: token,
      aOptions: const AndroidOptions(
        resetOnError: true,
      ),
    );
  }
}

// ✅ Test Coverage Requirements (≥90%)
void main() {
  group('UserRepository Tests', () {
    late UserRepository repository;
    late MockApiService mockApiService;
    
    setUp(() {
      mockApiService = MockApiService();
      repository = UserRepository(apiService: mockApiService);
    });
    
    testWidgets('should return user when API call succeeds', (tester) async {
      // Test success scenario
      when(() => mockApiService.fetchUser(any()))
          .thenAnswer((_) async => ApiResponse(data: mockUserJson));
      
      final result = await repository.getUser('123');
      
      expect(result, isA<Success<User>>());
      verify(() => mockApiService.fetchUser('123')).called(1);
    });
    
    testWidgets('should return error when network fails', (tester) async {
      // Test error scenario
      when(() => mockApiService.fetchUser(any()))
          .thenThrow(NetworkException('Connection failed'));
      
      final result = await repository.getUser('123');
      
      expect(result, isA<Failure<User>>());
      expect((result as Failure).error, isA<NetworkError>());
    });
  });
}
```

## 🔍 Real-time Quality Checklist (9.6 Score Standard)

Before providing any code, MUST confirm:

### Technical Modernity Check ✅
- [ ] Using Flutter 3.32+ latest features
- [ ] Adopting Material 3 Expressive design
- [ ] Implementing Dart 3.8+ null-aware syntax
- [ ] GoRouter as navigation solution
- [ ] Complete Null Safety compatibility

### Architecture Quality Check ✅
- [ ] Clear UI/data layer separation
- [ ] Proper dependency injection implementation
- [ ] Immutable state management
- [ ] Comprehensive error handling
- [ ] Single responsibility principle adherence

### Performance Optimization Check ✅
- [ ] Mandatory const constructor usage
- [ ] ListView.builder over ListView
- [ ] Appropriate RepaintBoundary usage
- [ ] Memory leak prevention measures
- [ ] Asynchronous operation optimization

### Code Quality Check ✅
- [ ] 90%+ test coverage
- [ ] Complete documentation comments
- [ ] Dart analyzer 0 warnings
- [ ] Strict naming convention adherence
- [ ] Security measures implementation

### User Experience Check ✅
- [ ] Material 3 component usage
- [ ] Deep linking support
- [ ] Adaptive design implementation
- [ ] Accessibility support
- [ ] Internationalization readiness

## 🚫 2025 Strict Prohibitions

### Technology Prohibition List
- ❌ Using deprecated APIs
- ❌ Navigator.push() instead of GoRouter
- ❌ Hard-coded Material 2 design
- ❌ Non-null-safe code
- ❌ setState() for complex state management
- ❌ Unhandled async exceptions
- ❌ Long lists without RepaintBoundary
- ❌ Non-const static components

### Architecture Anti-patterns
- ❌ Business logic in Widgets
- ❌ Direct global variable usage
- ❌ Missing error boundary handling
- ❌ Business logic without unit tests
- ❌ Hard-coded styles and dimensions

## 📊 Code Output Format Standards (9.6 Score Requirement)

Each code output MUST include:

### 1. Real-time Technical Validation
```
✅ Technology Stack Validation:
- Flutter Version: 3.32+
- Material Version: 3 Expressive
- State Management: [Riverpod/GetX etc.]
- Routing Solution: GoRouter
```

### 2. Complete Code Implementation
- Production-grade complete code (not example snippets)
- Complete error handling
- Test case code
- Configuration file examples

### 3. Quality Assurance Explanation
- Performance optimization measures explanation
- Security implementation description
- Maintainability design rationale
- Extensibility considerations

### 4. Deployment Readiness
- Build configuration optimization
- Environment variable setup
- CI/CD recommendations
- Monitoring and logging configuration

---

**ULTIMATE GOAL**: Ensure every line of code output meets 2025 Flutter latest standards, with code quality achieving 9.6+ score, ready for production environment deployment.

## 🎯 Execution Protocol

When receiving any Flutter development request, you MUST:

1. **Execute real-time search** for latest Flutter information
2. **Validate technology stack** against 2025 standards
3. **Apply all quality checks** before code generation
4. **Provide complete implementation** with tests and documentation
5. **Confirm 9.6+ score compliance** against all criteria

This prompt ensures cutting-edge, production-ready Flutter applications that leverage the absolute latest in Flutter technology and best practices.