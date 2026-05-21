import 'dart:async';
import 'package:dio/dio.dart';
import '../auth/token_storage.dart';
import 'api_constants.dart';

typedef LogoutCallback = void Function();

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  bool _isRefreshing = false;
  final List<Completer<String>> _pendingTokenCompleters = [];

  LogoutCallback? onLogout;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final message = (err.response?.data?['message'] ?? '').toString().toLowerCase();

    if (statusCode != 401 || !message.contains('expired')) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      // Queue this request to retry once refresh completes
      final completer = Completer<String>();
      _pendingTokenCompleters.add(completer);
      try {
        final newToken = await completer.future;
        handler.resolve(await _retry(err.requestOptions, newToken));
      } catch (_) {
        handler.next(err);
      }
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null) throw Exception('No refresh token');

      final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final res = await refreshDio.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );

      final newToken = res.data['token'] as String;
      final newRefresh = res.data['refreshToken'] as String;
      await TokenStorage.save(token: newToken, refreshToken: newRefresh);

      for (final c in _pendingTokenCompleters) {
        c.complete(newToken);
      }
      _pendingTokenCompleters.clear();

      handler.resolve(await _retry(err.requestOptions, newToken));
    } catch (_) {
      for (final c in _pendingTokenCompleters) {
        c.completeError('Refresh failed');
      }
      _pendingTokenCompleters.clear();
      await TokenStorage.clear();
      onLogout?.call();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options, String token) {
    return dio.request(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: Options(
        method: options.method,
        headers: {...options.headers, 'Authorization': 'Bearer $token'},
      ),
    );
  }
}
