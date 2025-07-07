/// 类型安全的结果类型，用于处理可能失败的操作
/// 参考Rust的Result<T, E>设计模式
sealed class Result<T, E> {
  const Result();
  
  /// 创建成功结果
  const factory Result.success(T value) = Success<T, E>;
  
  /// 创建失败结果
  const factory Result.failure(E error) = Failure<T, E>;
  
  /// 创建成功结果的便捷方法
  static Result<T, E> ok<T, E>(T value) => Result.success(value);
  
  /// 创建失败结果的便捷方法
  static Result<T, E> error<T, E>(E error) => Result.failure(error);
  
  /// 是否为成功结果
  bool get isSuccess => this is Success<T, E>;
  
  /// 是否为失败结果
  bool get isFailure => this is Failure<T, E>;
  
  /// 获取成功值（如果存在）
  T? get valueOrNull => switch (this) {
    Success<T, E>(:final value) => value,
    Failure<T, E>() => null,
  };
  
  /// 获取错误值（如果存在）
  E? get errorOrNull => switch (this) {
    Success<T, E>() => null,
    Failure<T, E>(:final error) => error,
  };
  
  /// 转换成功值
  Result<U, E> map<U>(U Function(T) mapper) => switch (this) {
    Success<T, E>(:final value) => Result.success(mapper(value)),
    Failure<T, E>(:final error) => Result.failure(error),
  };
  
  /// 转换错误值
  Result<T, U> mapError<U>(U Function(E) mapper) => switch (this) {
    Success<T, E>(:final value) => Result.success(value),
    Failure<T, E>(:final error) => Result.failure(mapper(error)),
  };
  
  /// 链式操作
  Result<U, E> flatMap<U>(Result<U, E> Function(T) mapper) => switch (this) {
    Success<T, E>(:final value) => mapper(value),
    Failure<T, E>(:final error) => Result.failure(error),
  };
  
  /// fold操作，类似于Either的fold
  U fold<U>(U Function(E) onFailure, U Function(T) onSuccess) => switch (this) {
    Success<T, E>(:final value) => onSuccess(value),
    Failure<T, E>(:final error) => onFailure(error),
  };
  
  /// 异步fold操作
  Future<U> foldAsync<U>(
    Future<U> Function(E) onFailure,
    Future<U> Function(T) onSuccess,
  ) => switch (this) {
    Success<T, E>(:final value) => onSuccess(value),
    Failure<T, E>(:final error) => onFailure(error),
  };
  
  /// 获取值或默认值
  T getOrElse(T Function() defaultValue) => switch (this) {
    Success<T, E>(:final value) => value,
    Failure<T, E>() => defaultValue(),
  };
  
  /// 获取值或抛出异常
  T getOrThrow() => switch (this) {
    Success<T, E>(:final value) => value,
    Failure<T, E>(:final error) => throw error is Exception 
        ? error as Exception
        : Exception('Result failure: $error'),
  };
  
  /// 转换为Future
  Future<T> toFuture() => switch (this) {
    Success<T, E>(:final value) => Future.value(value),
    Failure<T, E>(:final error) => Future.error(error is Exception 
        ? error as Exception
        : Exception('Result failure: $error')),
  };
  
  @override
  String toString() => switch (this) {
    Success<T, E>(:final value) => 'Success($value)',
    Failure<T, E>(:final error) => 'Failure($error)',
  };
  
  @override
  bool operator ==(Object other) => switch (this) {
    Success<T, E>(:final value) => other is Success<T, E> && value == other.value,
    Failure<T, E>(:final error) => other is Failure<T, E> && error == other.error,
  };
  
  @override
  int get hashCode => switch (this) {
    Success<T, E>(:final value) => value.hashCode,
    Failure<T, E>(:final error) => error.hashCode,
  };
}

/// 成功结果
final class Success<T, E> extends Result<T, E> {
  const Success(this.value);
  
  final T value;
}

/// 失败结果
final class Failure<T, E> extends Result<T, E> {
  const Failure(this.error);
  
  final E error;
}

/// 扩展方法，简化异步Result操作
extension ResultFuture<T, E> on Future<Result<T, E>> {
  /// 转换Future<Result<T, E>>为Future<T>
  Future<T> unwrap() async {
    final result = await this;
    return result.getOrThrow();
  }
  
  /// 映射成功值
  Future<Result<U, E>> mapAsync<U>(U Function(T) mapper) async {
    final result = await this;
    return result.map(mapper);
  }
  
  /// 异步映射成功值
  Future<Result<U, E>> flatMapAsync<U>(
    Future<Result<U, E>> Function(T) mapper,
  ) async {
    final result = await this;
    return result.fold(
      (error) => Result.failure(error),
      (value) => mapper(value),
    );
  }
}

/// 常用的Result类型别名
typedef AppResult<T> = Result<T, AppError>;
typedef NetworkResult<T> = Result<T, NetworkError>;
typedef StorageResult<T> = Result<T, StorageError>;

/// 通用错误类型
abstract class AppError {
  const AppError(this.message, [this.cause]);
  
  final String message;
  final Object? cause;
  
  @override
  String toString() => 'AppError: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// 网络错误
class NetworkError extends AppError {
  const NetworkError(super.message, [super.cause, this.statusCode]);
  
  final int? statusCode;
  
  @override
  String toString() => 'NetworkError: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// 存储错误
class StorageError extends AppError {
  const StorageError(super.message, [super.cause]);
  
  @override
  String toString() => 'StorageError: $message';
}

/// 验证错误
class ValidationError extends AppError {
  const ValidationError(super.message, [super.cause, this.field]);
  
  final String? field;
  
  @override
  String toString() => 'ValidationError: $message${field != null ? ' (field: $field)' : ''}';
}

/// 业务逻辑错误
class BusinessError extends AppError {
  const BusinessError(super.message, [super.cause, this.code]);
  
  final String? code;
  
  @override
  String toString() => 'BusinessError: $message${code != null ? ' (code: $code)' : ''}';
}

/// 创建Result的工具函数
class ResultUtils {
  /// 安全执行可能抛出异常的函数
  static Result<T, E> tryCatch<T, E>(
    T Function() fn,
    E Function(Object error, StackTrace stackTrace) onError,
  ) {
    try {
      return Result.success(fn());
    } catch (e, stackTrace) {
      return Result.failure(onError(e, stackTrace));
    }
  }
  
  /// 安全执行可能抛出异常的异步函数
  static Future<Result<T, E>> tryCatchAsync<T, E>(
    Future<T> Function() fn,
    E Function(Object error, StackTrace stackTrace) onError,
  ) async {
    try {
      final value = await fn();
      return Result.success(value);
    } catch (e, stackTrace) {
      return Result.failure(onError(e, stackTrace));
    }
  }
  
  /// 将多个Result合并
  static Result<List<T>, E> sequence<T, E>(List<Result<T, E>> results) {
    final values = <T>[];
    
    for (final result in results) {
      switch (result) {
        case Success<T, E>(:final value):
          values.add(value);
        case Failure<T, E>(:final error):
          return Result.failure(error);
      }
    }
    
    return Result.success(values);
  }
  
  /// 将第一个成功的Result返回
  static Result<T, List<E>> firstSuccess<T, E>(List<Result<T, E>> results) {
    final errors = <E>[];
    
    for (final result in results) {
      switch (result) {
        case Success<T, E>(:final value):
          return Result.success(value);
        case Failure<T, E>(:final error):
          errors.add(error);
      }
    }
    
    return Result.failure(errors);
  }
} 