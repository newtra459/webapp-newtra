/// A type that represents either a success or a failure, including an error.
sealed class Result<T> {
  const Result();

  /// Creates a success result with the given [data].
  factory Result.success(T data) = Success<T>;

  /// Creates a failure result with the given [error].
  factory Result.failure(Exception error) = Failure<T>;

  /// Returns true if this is a success result.
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result.
  bool get isFailure => this is Failure<T>;

  /// Returns the data if this is a success, otherwise throws.
  T get data => (this as Success<T>).data;

  /// Returns the error if this is a failure, otherwise throws.
  Exception get error => (this as Failure<T>).error;

  /// Returns the data if success, otherwise null.
  T? get dataOrNull => isSuccess ? data : null;

  /// Returns the error if failure, otherwise null.
  Exception? get errorOrNull => isFailure ? error : null;

  /// Transforms the success value using the given function.
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(data: final data) => Result.success(transform(data)),
      Failure(error: final error) => Result.failure(error),
    };
  }

  /// Maps both success and failure cases.
  R when<R>({
    required R Function(T data) success,
    required R Function(Exception error) failure,
  }) {
    return switch (this) {
      Success(data: final data) => success(data),
      Failure(error: final error) => failure(error),
    };
  }

  /// Maps only the success case, returns null for failure.
  R? whenSuccess<R>(R Function(T data) callback) {
    return isSuccess ? callback(data) : null;
  }

  /// Maps only the failure case, returns null for success.
  R? whenFailure<R>(R Function(Exception error) callback) {
    return isFailure ? callback(error) : null;
  }
}

class Success<T> extends Result<T> {
  @override
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success(data: $data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

class Failure<T> extends Result<T> {
  @override
  final Exception error;
  const Failure(this.error);

  @override
  String toString() => 'Failure(error: $error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Extension methods for Future<Result<T>>
extension FutureResultExtension<T> on Future<Result<T>> {
  /// Executes the callback when the result is a success.
  Future<Result<T>> onSuccess(void Function(T data) callback) async {
    final result = await this;
    result.whenSuccess(callback);
    return result;
  }

  /// Executes the callback when the result is a failure.
  Future<Result<T>> onFailure(void Function(Exception error) callback) async {
    final result = await this;
    result.whenFailure(callback);
    return result;
  }

  /// Transforms the result using an async function.
  Future<Result<R>> mapAsync<R>(Future<R> Function(T data) transform) async {
    final result = await this;
    if (result.isSuccess) {
      try {
        final transformed = await transform(result.data);
        return Result.success(transformed);
      } catch (e) {
        return Result.failure(e as Exception);
      }
    }
    return Result.failure(result.error);
  }
}
