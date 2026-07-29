import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import 'api_config.dart';

/// Thrown for non-2xx responses with a clean, user-showable message.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Machine-readable reason from the backend (e.g. ACCOUNT_NOT_FOUND,
  /// ACCOUNT_EXISTS, PASSWORD_CHANGE_REQUIRED). Lets callers branch on the
  /// cause instead of pattern-matching human-readable text.
  final String? code;

  /// Extra context some errors carry — currently the email involved.
  final String? email;

  ApiException(this.message, [this.statusCode, this.code, this.email]);
  @override
  String toString() => message;
}

/// Dio-based client. Attaches the bearer token, unwraps the backend
/// `{ success, data }` envelope, and transparently refreshes on 401.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        // X-Client-Type flags this as the mobile client → backend grants the
        // long-lived (6-month) refresh session; web keeps its short default.
        headers: {'Content-Type': 'application/json', 'X-Client-Type': 'mobile'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.instance.accessToken;
          if (token != null && options.extra['auth'] != false) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401 && e.requestOptions.extra['retry'] != true) {
            final refreshed = await _refresh();
            if (refreshed) {
              final req = e.requestOptions;
              req.extra['retry'] = true;
              final token = await SecureStorage.instance.accessToken;
              req.headers['Authorization'] = 'Bearer $token';
              try {
                final clone = await _dio.fetch(req);
                return handler.resolve(clone);
              } catch (_) {}
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

  bool _refreshing = false;
  Future<bool> _refresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refresh = await SecureStorage.instance.refreshToken;
      if (refresh == null) return false;
      final res = await Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {'X-Client-Type': 'mobile'},
      )).post(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = res.data['data'] ?? res.data;
      final access = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (access != null) {
        await SecureStorage.instance.saveTokens(access: access, refresh: newRefresh);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  /// Unwrap `{ success, data }` → data.
  dynamic _unwrap(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  ApiException _toException(DioException e) {
    final data = e.response?.data;
    String message = 'Une erreur est survenue';
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      message = m is List ? m.join(', ') : m.toString();
    } else if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      message = 'Impossible de contacter le serveur';
    } else if (e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      message = 'Le serveur met trop de temps à répondre. Réessayez.';
    }
    // The backend attaches `code` (and sometimes `email`) to errors the UI has
    // to react to differently — losing them here would force brittle string
    // matching on the message.
    String? code;
    String? email;
    if (data is Map) {
      code = data['code'] as String?;
      email = data['email'] as String?;
    }
    return ApiException(message, e.response?.statusCode, code, email);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    try {
      final res = await _dio.get(path,
          queryParameters: query, options: Options(extra: {'auth': auth}));
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query, bool auth = true}) async {
    try {
      final res = await _dio.post(path, data: body, queryParameters: query, options: Options(extra: {'auth': auth}));
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    try {
      final res = await _dio.patch(path, data: body);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<dynamic> put(String path, {Object? body}) async {
    try {
      final res = await _dio.put(path, data: body);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// [body] is needed by endpoints that require an explicit confirmation
  /// payload, such as permanent account deletion.
  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await _dio.delete(path, data: body);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }
}
