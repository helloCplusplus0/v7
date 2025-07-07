import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

void main() {
  group('Result Tests', () {
    group('Success Cases', () {
      test('should create success result with value', () {
        // Arrange & Act
        final result = Result<String, String>.success('test data');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.valueOrNull, equals('test data'));
        expect(result.errorOrNull, isNull);
      });

      test('should handle null value in success', () {
        // Arrange & Act
        final result = Result<String?, String>.success(null);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('should support different data types', () {
        // Arrange & Act
        final intResult = Result<int, String>.success(42);
        final listResult = Result<List<int>, String>.success([1, 2, 3]);
        final mapResult = Result<Map<String, String>, String>.success({'key': 'value'});

        // Assert
        expect(intResult.valueOrNull, equals(42));
        expect(listResult.valueOrNull, equals([1, 2, 3]));
        expect(mapResult.valueOrNull, equals({'key': 'value'}));
      });
    });

    group('Failure Cases', () {
      test('should create failure result with error', () {
        // Arrange & Act
        final result = Result<String, String>.failure('Invalid input');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.valueOrNull, isNull);
        expect(result.errorOrNull, equals('Invalid input'));
      });

      test('should handle different error types', () {
        // Arrange & Act
        final validationResult = Result<String, ValidationError>.failure(
          const ValidationError('Validation failed', null, 'email'),
        );
        final networkResult = Result<String, NetworkError>.failure(
          const NetworkError('Connection timeout', null, 404),
        );
        final businessResult = Result<String, BusinessError>.failure(
          const BusinessError('Insufficient balance', null, 'BALANCE_LOW'),
        );

        // Assert
        expect(validationResult.errorOrNull?.field, equals('email'));
        expect(networkResult.errorOrNull?.statusCode, equals(404));
        expect(businessResult.errorOrNull?.code, equals('BALANCE_LOW'));
      });
    });

    group('Result Mapping', () {
      test('should map success value', () {
        // Arrange
        final result = Result<int, String>.success(5);

        // Act
        final mappedResult = result.map<String>((value) => 'Number: $value');

        // Assert
        expect(mappedResult.isSuccess, isTrue);
        expect(mappedResult.valueOrNull, equals('Number: 5'));
      });

      test('should preserve error when mapping failure', () {
        // Arrange
        final result = Result<int, String>.failure('Invalid');

        // Act
        final mappedResult = result.map<String>((value) => 'Number: $value');

        // Assert
        expect(mappedResult.isFailure, isTrue);
        expect(mappedResult.errorOrNull, equals('Invalid'));
      });

      test('should chain map operations', () {
        // Arrange
        final result = Result<int, String>.success(10);

        // Act
        final mappedResult = result
            .map<int>((value) => value * 2)
            .map<String>((value) => 'Result: $value');

        // Assert
        expect(mappedResult.valueOrNull, equals('Result: 20'));
      });

      test('should map error values', () {
        // Arrange
        final result = Result<int, String>.failure('original error');

        // Act
        final mappedResult = result.mapError<int>((error) => error.length);

        // Assert
        expect(mappedResult.isFailure, isTrue);
        expect(mappedResult.errorOrNull, equals(14)); // Length of 'original error'
      });
    });

    group('Result Folding', () {
      test('should fold success result', () {
        // Arrange
        final result = Result<int, String>.success(42);

        // Act
        final folded = result.fold<String>(
          (error) => 'Error: $error',
          (value) => 'Success: $value',
        );

        // Assert
        expect(folded, equals('Success: 42'));
      });

      test('should fold failure result', () {
        // Arrange
        final result = Result<int, String>.failure('Connection failed');

        // Act
        final folded = result.fold<String>(
          (error) => 'Error: $error',
          (value) => 'Success: $value',
        );

        // Assert
        expect(folded, equals('Error: Connection failed'));
      });

      test('should handle async fold operations', () async {
        // Arrange
        final result = Result<int, String>.success(42);

        // Act
        final folded = await result.foldAsync<String>(
          (error) async => 'Error: $error',
          (value) async => 'Success: $value',
        );

        // Assert
        expect(folded, equals('Success: 42'));
      });
    });

    group('FlatMap Operations', () {
      test('should flatMap success result', () {
        // Arrange
        final result = Result<int, String>.success(5);

        // Act
        final flatMapped = result.flatMap<String>(
          (value) => Result<String, String>.success('Value: $value'),
        );

        // Assert
        expect(flatMapped.isSuccess, isTrue);
        expect(flatMapped.valueOrNull, equals('Value: 5'));
      });

      test('should propagate error in flatMap', () {
        // Arrange
        final result = Result<int, String>.failure('Initial error');

        // Act
        final flatMapped = result.flatMap<String>(
          (value) => Result<String, String>.success('Value: $value'),
        );

        // Assert
        expect(flatMapped.isFailure, isTrue);
        expect(flatMapped.errorOrNull, equals('Initial error'));
      });

      test('should handle error in flatMap function', () {
        // Arrange
        final result = Result<int, String>.success(5);

        // Act
        final flatMapped = result.flatMap<String>(
          (value) => Result<String, String>.failure('New error'),
        );

        // Assert
        expect(flatMapped.isFailure, isTrue);
        expect(flatMapped.errorOrNull, equals('New error'));
      });
    });

    group('Value Extraction', () {
      test('should get value or default', () {
        // Arrange
        final successResult = Result<String, String>.success('value');
        final failureResult = Result<String, String>.failure('error');

        // Act & Assert
        expect(successResult.getOrElse(() => 'default'), equals('value'));
        expect(failureResult.getOrElse(() => 'default'), equals('default'));
      });

      test('should get value or throw', () {
        // Arrange
        final successResult = Result<String, String>.success('value');
        final failureResult = Result<String, String>.failure('error');

        // Act & Assert
        expect(successResult.getOrThrow(), equals('value'));
        expect(() => failureResult.getOrThrow(), throwsException);
      });

      test('should convert to future', () async {
        // Arrange
        final successResult = Result<String, String>.success('value');
        final failureResult = Result<String, String>.failure('error');

        // Act & Assert
        expect(await successResult.toFuture(), equals('value'));
        expect(failureResult.toFuture(), throwsException);
      });
    });

    group('Result Equality', () {
      test('should compare success results correctly', () {
        // Arrange
        final result1 = Result<String, String>.success('test');
        final result2 = Result<String, String>.success('test');
        final result3 = Result<String, String>.success('different');

        // Assert
        expect(result1, equals(result2));
        expect(result1, isNot(equals(result3)));
      });

      test('should compare failure results correctly', () {
        // Arrange
        final result1 = Result<String, String>.failure('error');
        final result2 = Result<String, String>.failure('error');
        final result3 = Result<String, String>.failure('different');

        // Assert
        expect(result1, equals(result2));
        expect(result1, isNot(equals(result3)));
      });

      test('should not be equal across success/failure', () {
        // Arrange
        final successResult = Result<String, String>.success('value');
        final failureResult = Result<String, String>.failure('value');

        // Assert
        expect(successResult, isNot(equals(failureResult)));
      });
    });

    group('Result toString', () {
      test('should have meaningful string representation', () {
        // Arrange
        final successResult = Result<String, String>.success('test data');
        final failureResult = Result<String, String>.failure('error message');

        // Act & Assert
        expect(successResult.toString(), equals('Success(test data)'));
        expect(failureResult.toString(), equals('Failure(error message)'));
      });
    });

    group('Factory Methods', () {
      test('should create success with ok method', () {
        // Act
        final result = Result.ok<String, String>('value');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals('value'));
      });

      test('should create failure with error method', () {
        // Act
        final result = Result.error<String, String>('error');

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, equals('error'));
      });
    });
  });

  group('Result Future Extensions', () {
    test('should unwrap successful future result', () async {
      // Arrange
      final futureResult = Future.value(Result<String, String>.success('value'));

      // Act
      final unwrapped = await futureResult.unwrap();

      // Assert
      expect(unwrapped, equals('value'));
    });

    test('should throw on unwrap failure', () async {
      // Arrange
      final futureResult = Future.value(Result<String, String>.failure('error'));

      // Act & Assert
      expect(futureResult.unwrap(), throwsException);
    });

    test('should map async future result', () async {
      // Arrange
      final futureResult = Future.value(Result<int, String>.success(5));

      // Act
      final mapped = await futureResult.mapAsync<String>((value) => 'Number: $value');

      // Assert
      expect(mapped.valueOrNull, equals('Number: 5'));
    });

    test('should flatMap async future result', () async {
      // Arrange
      final futureResult = Future.value(Result<int, String>.success(5));

      // Act
      final flatMapped = await futureResult.flatMapAsync<String>(
        (value) async => Result<String, String>.success('Async: $value'),
      );

      // Assert
      expect(flatMapped.valueOrNull, equals('Async: 5'));
    });
  });

  group('Error Types', () {
    test('should create AppError with message', () {
      // Arrange & Act
      const error = NetworkError('Connection failed');

      // Assert
      expect(error.message, equals('Connection failed'));
      expect(error.toString(), contains('NetworkError'));
      expect(error.toString(), contains('Connection failed'));
    });

    test('should create ValidationError with field', () {
      // Arrange & Act
      const error = ValidationError('Invalid email', null, 'email');

      // Assert
      expect(error.field, equals('email'));
      expect(error.toString(), contains('field: email'));
    });

    test('should create BusinessError with code', () {
      // Arrange & Act
      const error = BusinessError('Insufficient funds', null, 'BALANCE_LOW');

      // Assert
      expect(error.code, equals('BALANCE_LOW'));
      expect(error.toString(), contains('BALANCE_LOW'));
    });

         test('should handle error causes', () {
       // Arrange
       final originalException = Exception('Original error');

       // Act
       final error = NetworkError('Network failed', originalException);

       // Assert
       expect(error.cause, equals(originalException));
       expect(error.message, equals('Network failed'));
     });
  });

  group('Type Aliases', () {
    test('should use AppResult alias', () {
      // Act
      final result = AppResult<String>.success('test');

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, equals('test'));
    });

    test('should use NetworkResult alias', () {
      // Act
      final result = NetworkResult<String>.failure(
        const NetworkError('Network error'),
      );

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.message, equals('Network error'));
    });

    test('should use StorageResult alias', () {
      // Act
      final result = StorageResult<String>.failure(
        const StorageError('Storage error'),
      );

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.message, equals('Storage error'));
    });
  });

  group('Pattern Matching', () {
    test('should support pattern matching with switch expressions', () {
      // Arrange
      final successResult = Result<int, String>.success(42);
      final failureResult = Result<int, String>.failure('Error message');

      // Act
      final successMessage = switch (successResult) {
        Success<int, String>(:final value) => 'Got: $value',
        Failure<int, String>(:final error) => 'Error: $error',
      };

      final failureMessage = switch (failureResult) {
        Success<int, String>(:final value) => 'Got: $value',
        Failure<int, String>(:final error) => 'Error: $error',
      };

      // Assert
      expect(successMessage, equals('Got: 42'));
      expect(failureMessage, equals('Error: Error message'));
    });

    test('should support pattern matching with if-case', () {
      // Arrange
      final result = Result<String, String>.success('test');

      // Act & Assert
      if (result case Success<String, String>(:final value)) {
        expect(value, equals('test'));
      } else {
        fail('Should match success pattern');
      }
    });
  });

  group('Edge Cases', () {
    test('should handle very large data', () {
      // Arrange
      final largeList = List.generate(10000, (i) => i);

      // Act
      final result = Result<List<int>, String>.success(largeList);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.length, equals(10000));
    });

    test('should handle complex nested types', () {
      // Arrange
      final complexData = {
        'nested': {
          'list': [1, 2, 3],
          'map': {'key': 'value'},
        },
      };

      // Act
      final result = Result<Map<String, dynamic>, String>.success(complexData);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?['nested']?['list'], equals([1, 2, 3]));
    });
  });
} 