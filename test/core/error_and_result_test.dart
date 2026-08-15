import 'package:flutter_test/flutter_test.dart';
import 'package:mjollnir_app/core/errors/app_error.dart';
import 'package:mjollnir_app/core/utils/result.dart';

void main() {
  group('AppError hierarchy', () {
    test('NetworkError has correct message', () {
      const err = NetworkError('Connection failed');
      expect(err.message, 'Connection failed');
      expect(err.toString(), 'Connection failed');
    });

    test('ValidationError holds field errors', () {
      const err = ValidationError('Bad input', {'email': 'Invalid email'});
      expect(err.getFieldError('email'), 'Invalid email');
      expect(err.getFieldError('phone'), isNull);
    });

    test('sealed class pattern matching works', () {
      final AppError error = const NetworkError('Timeout', code: '408');

      final message = switch (error) {
        NetworkError() => 'Network: ${error.message}',
        ValidationError() => 'Validation: ${error.message}',
        AuthenticationError() => 'Auth: ${error.message}',
        AuthorizationError() => 'Forbidden: ${error.message}',
        CacheError() => 'Cache: ${error.message}',
        FileError() => 'File: ${error.message}',
        ParseError() => 'Parse: ${error.message}',
        GenericError() => 'Generic: ${error.message}',
      };

      expect(message, 'Network: Timeout');
    });
  });

  group('Result<T>', () {
    test('Success holds data', () {
      final result = Result<int>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.data, 42);
    });

    test('Failure holds error', () {
      final result = Result<int>.failure(Exception('fail'));
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.error.toString(), contains('fail'));
    });

    test('when maps both cases', () {
      final success = Result<String>.success('hello');
      final failure = Result<String>.failure(Exception('oops'));

      final successResult = success.when(
        success: (data) => 'got: $data',
        failure: (e) => 'err: $e',
      );
      expect(successResult, 'got: hello');

      final failureResult = failure.when(
        success: (data) => 'got: $data',
        failure: (e) => 'err',
      );
      expect(failureResult, 'err');
    });

    test('map transforms success value', () {
      final result = Result<int>.success(5);
      final mapped = result.map((n) => n * 2);
      expect(mapped.data, 10);
    });

    test('map preserves failure', () {
      final result = Result<int>.failure(Exception('err'));
      final mapped = result.map((n) => n * 2);
      expect(mapped.isFailure, isTrue);
    });

    test('dataOrNull returns null for failure', () {
      final result = Result<int>.failure(Exception('x'));
      expect(result.dataOrNull, isNull);
    });

    test('dataOrNull returns data for success', () {
      final result = Result<int>.success(7);
      expect(result.dataOrNull, 7);
    });

    test('equality works for Success', () {
      final a = Result<int>.success(1);
      final b = Result<int>.success(1);
      expect(a, equals(b));
    });
  });
}
