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

  static Future<String?>? _refreshFuture;

  static Future<String?> _performTokenRefresh() async {
    try {
      final refreshToken = await LocalStorage.getRefreshToken();
      if (refreshToken == null) return null;

      final refreshDio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
      final response = await refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      final newAccessToken = response.data['accessToken'] as String?;
      final newRefreshToken = response.data['refreshToken'] as String?;

      if (newAccessToken != null && newRefreshToken != null) {
        await LocalStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );
        return newAccessToken;
      }
      return null;
    } catch (e) {
      // Only clear auth if server explicitly rejected the refresh token with 401/403.
      // Never wipe user tokens on connection glitches, offline mode, or timeouts!
      if (e is DioException &&
          e.response != null &&
          (e.response!.statusCode == 401 || e.response!.statusCode == 403)) {
        await LocalStorage.clearAuth();
      }
      return null;
    } finally {
      _refreshFuture = null;
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/auth/')) {
      _refreshFuture ??= _performTokenRefresh();
      final newAccessToken = await _refreshFuture;

      if (newAccessToken != null) {
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        try {
          final cloneReq = await _dio.fetch(retryOptions);
          return handler.resolve(cloneReq);
        } catch (e) {
          if (e is DioException) {
            return handler.next(e);
          }
        }
      }
    }
    return handler.next(err);
  }
}
