import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final dynamic details;
  final int? statusCode;

  ApiException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
  });

  @override
  String toString() => '[$code] $message';
}

class ApiClient {
  late final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient({TokenStorage? storage}) : tokenStorage = storage ?? TokenStorage() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 请求拦截器：注入 JWT Bearer Token
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          final resp = e.response;
          if (resp != null && resp.data is Map<String, dynamic>) {
            final data = resp.data as Map<String, dynamic>;
            final apiError = ApiException(
              code: data['code']?.toString() ?? 'UNKNOWN_ERROR',
              message: data['message']?.toString() ?? e.message ?? '网络请求失败',
              details: data['details'],
              statusCode: resp.statusCode,
            );
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                error: apiError,
                type: e.type,
              ),
            );
          }
          return handler.next(e);
        },
      ),
    );
  }
}
