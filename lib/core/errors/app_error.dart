import 'package:dio/dio.dart';

/// Base class for all application errors
sealed class AppError implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppError(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Network-related errors
class NetworkError extends AppError {
  const NetworkError(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);

  factory NetworkError.fromDioException(DioException e) {
    String? responseMessage() {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      return null;
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkError('Connection timeout. Please check your internet connection.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = responseMessage();
        if (statusCode == 401) {
          return NetworkError(
            message ?? 'Unauthorized. Please login again.',
            code: '401',
          );
        } else if (statusCode == 403) {
          return NetworkError(message ?? 'Access forbidden.', code: '403');
        } else if (statusCode == 404) {
          return NetworkError(message ?? 'Resource not found.', code: '404');
        } else if (statusCode! >= 500) {
          return NetworkError(
            message ?? 'Server error. Please try again later.',
            code: '$statusCode',
          );
        }
        return NetworkError(message ?? 'Request failed', code: '$statusCode');
      case DioExceptionType.cancel:
        return const NetworkError('Request cancelled.');
      case DioExceptionType.connectionError:
        return const NetworkError('No internet connection. Please check your network settings.');
      default:
        return NetworkError(e.message ?? 'Unknown network error occurred.', originalError: e);
    }
  }
}

/// Validation errors with field-specific messages
class ValidationError extends AppError {
  final Map<String, String> fieldErrors;

  const ValidationError(String message, this.fieldErrors, {String? code})
      : super(message, code: code);

  factory ValidationError.fromJson(Map<String, dynamic> json) {
    final errors = <String, String>{};
    if (json['errors'] is Map) {
      final errorMap = json['errors'] as Map<String, dynamic>;
      errorMap.forEach((key, value) {
        errors[key] = value.toString();
      });
    }
    return ValidationError(
      json['message'] ?? 'Validation failed',
      errors,
      code: json['code'],
    );
  }

  String? getFieldError(String field) => fieldErrors[field];
}

/// Authentication errors
class AuthenticationError extends AppError {
  const AuthenticationError(String message, {String? code})
      : super(message, code: code);
}

/// Authorization errors (permissions)
class AuthorizationError extends AppError {
  const AuthorizationError(String message, {String? code})
      : super(message, code: code);
}

/// Cache-related errors
class CacheError extends AppError {
  const CacheError(String message, {dynamic originalError})
      : super(message, originalError: originalError);
}

/// File operation errors
class FileError extends AppError {
  const FileError(String message, {dynamic originalError})
      : super(message, originalError: originalError);
}

/// Parse/Serialization errors
class ParseError extends AppError {
  const ParseError(String message, {dynamic originalError})
      : super(message, originalError: originalError);
}

/// Generic application error
class GenericError extends AppError {
  const GenericError(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Extension to easily convert exceptions to AppError
extension ExceptionToAppError on Exception {
  AppError toAppError() {
    if (this is AppError) return this as AppError;
    if (this is DioException) {
      return NetworkError.fromDioException(this as DioException);
    }
    return GenericError(toString());
  }
}
