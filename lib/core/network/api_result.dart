// DEPRECATED: Use [Result<T>] from 'package:mjollnir_app/core/utils/result.dart'
// instead. [ApiResult] is no longer used and will be removed in a future release.
@Deprecated('Use Result<T> from core/utils/result.dart instead')
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isLoading;

  const ApiResult._({
    this.data,
    this.error,
    this.isLoading = false,
  });

  factory ApiResult.success(T data) => ApiResult._(data: data);
  factory ApiResult.failure(String error) => ApiResult._(error: error);
  factory ApiResult.loading() => const ApiResult._(isLoading: true);

  bool get isSuccess => data != null && error == null;
  bool get isError => error != null;

  R when<R>({
    required R Function(T data) success,
    required R Function(String error) error,
    required R Function() loading,
  }) {
    if (isLoading) return loading();
    if (isError) return error(this.error!);
    return success(data as T);
  }
}
