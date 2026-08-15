import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../errors/app_error.dart';
import '../storage/local_storage.dart';
import 'api_endpoints.dart';
import 'contract_mapper.dart';

class ApiClient {
  static String get baseUrl => ApiConfig.baseUrl;

  late final Dio _dio;
  bool _isRefreshing = false;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.connectTimeoutSec),
        receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeoutSec),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final originalPath = options.path;
          final mappedPath = ContractMapper.mapPath(
            path: originalPath,
            evMode: ApiConfig.contract == ApiContract.ev,
          );
          options.path = mappedPath;

          if (ApiConfig.enableContractTrace && kDebugMode) {
            debugPrint(
              '[API-MAP] ${options.method} $originalPath -> $mappedPath '
              '(contract=${ApiConfig.contract.name})',
            );
          }

          if (ApiConfig.contract == ApiContract.ev) {
            if (ApiConfig.evAppSecret.isNotEmpty) {
              options.headers['X-Karma-App'] = ApiConfig.evAppSecret;
            }
            if (ContractMapper.requiresAdminHeader(mappedPath) &&
                ApiConfig.evAdminSecret.isNotEmpty) {
              options.headers['X-Karma-Admin-Auth'] = ApiConfig.evAdminSecret;
            }
          }

          final token = LocalStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_isRefreshing) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request with the new token
              final opts = error.requestOptions;
              opts.headers['Authorization'] =
                  'Bearer ${LocalStorage.getToken()}';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
            await LocalStorage.clearAuth();
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refresh = LocalStorage.getRefreshToken();
    if (refresh == null) return false;
    _isRefreshing = true;
    try {
      final mappedRefreshPath = ContractMapper.mapPath(
        path: '/auth/refresh',
        evMode: ApiConfig.contract == ApiContract.ev,
      );
      final headers = <String, dynamic>{};
      if (ApiConfig.contract == ApiContract.ev && ApiConfig.evAppSecret.isNotEmpty) {
        headers['X-Karma-App'] = ApiConfig.evAppSecret;
      }

      final response = await Dio(BaseOptions(baseUrl: baseUrl, headers: headers)).post(
        mappedRefreshPath,
        data: {'refresh_token': refresh},
      );
      final newToken = response.data['data']?['token'] as String?;
      final newRefresh = response.data['data']?['refresh_token'] as String?;
      if (newToken != null) {
        await LocalStorage.saveToken(newToken);
        if (newRefresh != null) {
          await LocalStorage.saveRefreshToken(newRefresh);
        }
        _isRefreshing = false;
        return true;
      }
    } catch (_) {
      // Refresh failed
    }
    _isRefreshing = false;
    return false;
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw NetworkError.fromDioException(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final mappedData = ContractMapper.mapRequestData(
        originalPath: path,
        data: data,
        evMode: ApiConfig.contract == ApiContract.ev,
      );
      if (ApiConfig.enableContractTrace && kDebugMode && mappedData != data) {
        debugPrint('[API-MAP] payload transformed for $path');
      }
      // Backend uses GET for group join/leave — override method when needed.
      if (ApiConfig.contract == ApiContract.ev &&
          ContractMapper.shouldUseGet(path)) {
        return await _dio.get(path, queryParameters: queryParameters);
      }
      return await _dio.post(path, data: mappedData, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw NetworkError.fromDioException(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
  }) async {
    try {
      final mappedData = ContractMapper.mapRequestData(
        originalPath: path,
        data: data,
        evMode: ApiConfig.contract == ApiContract.ev,
      );
      return await _dio.put(path, data: mappedData);
    } on DioException catch (e) {
      throw NetworkError.fromDioException(e);
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
  }) async {
    try {
      final mappedData = ContractMapper.mapRequestData(
        originalPath: path,
        data: data,
        evMode: ApiConfig.contract == ApiContract.ev,
      );
      return await _dio.patch(path, data: mappedData);
    } on DioException catch (e) {
      throw NetworkError.fromDioException(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw NetworkError.fromDioException(e);
    }
  }
}
