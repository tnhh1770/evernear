import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../constants/api_endpoints.dart';
import '../i18n/app_localizations.dart';
import '../storage/local_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  static const _uuid = Uuid();

  AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Automatically inject idempotency header for POST / PUT / PATCH if not already set
    if (['POST', 'PUT', 'PATCH'].contains(options.method.toUpperCase())) {
      if (!options.headers.containsKey('X-Event-ID')) {
        options.headers['X-Event-ID'] = _uuid.v4();
      }
    }

    // Attach active locale so backend can negotiate language
    options.headers['Accept-Language'] = AppLocalizations.globalLocaleCode;

    final token = await LocalStorage.getAccessToken();
    if (token != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/auth/')) {
      final refreshToken = await LocalStorage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final refreshDio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
          final response = await refreshDio.post(
            ApiEndpoints.refresh,
            data: {'refreshToken': refreshToken},
          );

          final newAccessToken = response.data['accessToken'];
          final newRefreshToken = response.data['refreshToken'];

          if (newAccessToken != null && newRefreshToken != null) {
            await LocalStorage.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );

            final retryOptions = err.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            final cloneReq = await _dio.fetch(retryOptions);
            return handler.resolve(cloneReq);
          }
        } catch (e) {
          // Only clear auth if server explicitly rejected the refresh token with 401/403.
          // Never wipe user tokens on connection glitches, offline mode, or timeouts!
          if (e is DioException &&
              e.response != null &&
              (e.response!.statusCode == 401 || e.response!.statusCode == 403)) {
            await LocalStorage.clearAuth();
          }
        }
      }
    }
    return handler.next(err);
  }
}
