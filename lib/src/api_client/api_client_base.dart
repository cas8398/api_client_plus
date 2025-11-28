// api_client_plus.dart
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fastlog/flutter_fastlog.dart';
import 'package:mmkv/mmkv.dart';
import '../models/api_config.dart';
import '../models/api_error.dart';
import '../models/cache_config.dart';
import '../models/log_config.dart';
import '../models/route_pattern.dart';
import 'api_client_cache.dart';
import 'api_client_cache_strategy.dart';

part 'api_client_interceptors.dart';
part 'api_client_interceptors_retry.dart';
part 'api_client_execute.dart';
part 'api_client_errors.dart';

class ApiClientPlus with ApiClientCache {
  static final ApiClientPlus _instance = ApiClientPlus._internal();
  factory ApiClientPlus() => _instance;
  ApiClientPlus._internal();

  final Map<String, Dio> _clients = {};
  final Map<String, ApiConfig> _configs = {};
  final List<RoutePattern> _routes = [];

  late String _defaultDomain;
  bool _isInitialized = false;

  // Authentication
  Future<String?> Function()? _tokenGetter;
  Future<void> Function()? _onTokenInvalid;
  Future<void> Function(DioException error)? _onAuthError;
  Future<void> Function()? _onTokenRefresh;
  Future<bool> Function()? _shouldRetryAuth;

  // Global callbacks
  Future<void> Function(RequestOptions options)? _onRequest;
  Future<void> Function(Response response)? _onResponse;
  Future<void> Function(DioException error)? _onError;
  Future<void> Function(Response response)? _onCachedResponse;

  // Cache configuration
  late CacheConfig _cacheConfig;
  late LogConfig _logConfig;

  @override
  String get cacheInstanceName => 'api_client_plus_cache';

  /// Initialize the API client
  Future<void> initialize({
    required List<ApiConfig> configs,
    required String defaultDomain,
    CacheConfig cacheConfig = const CacheConfig(),
    LogConfig logConfig = const LogConfig(),

    // Authentication
    required Future<String?> Function() tokenGetter,
    required Future<void> Function() onTokenInvalid,
    Future<void> Function(DioException error)? onAuthError,
    Future<void> Function()? onTokenRefresh,
    Future<bool> Function()? shouldRetryAuth,

    // Global callbacks
    Future<void> Function(RequestOptions options)? onRequest,
    Future<void> Function(Response response)? onResponse,
    Future<void> Function(DioException error)? onError,
    Future<void> Function(Response response)? onCachedResponse,
  }) async {
    if (_isInitialized) {
      if (logConfig.showLog) {
        FastLog.w('ApiClientPlus already initialized');
      }
      return;
    }

    // Apply logging configuration
    logConfig.apply();

    // Store configs in map for lazy access
    for (final config in configs) {
      _configs[config.name] = config;
    }

    _routes.addAll(_routes);
    _defaultDomain = defaultDomain;
    _cacheConfig = cacheConfig;
    _logConfig = logConfig;

    // Set authentication callbacks
    _tokenGetter = tokenGetter;
    _onTokenInvalid = onTokenInvalid;
    _onAuthError = onAuthError;
    _onTokenRefresh = onTokenRefresh;
    _shouldRetryAuth = shouldRetryAuth;

    // Set global callbacks
    _onRequest = onRequest;
    _onResponse = onResponse;
    _onError = onError;
    _onCachedResponse = onCachedResponse;

    try {
      if (cacheConfig.enableCache) {
        // Initialize MMKV
        final rootDir = await MMKV.initialize(
          logLevel: kReleaseMode
              ? MMKVLogLevel.None
              : (logConfig.showCacheLog
                  ? MMKVLogLevel.Info
                  : MMKVLogLevel.None),
        );
        if (logConfig.showLog) {
          FastLog.i('📦 MMKV initialized: $rootDir', tag: 'CACHE');
        }
      }

      // Create Dio clients for each config
      for (final config in configs) {
        final dio = _createDioClient(config);
        _setupInterceptors(dio, config, _logConfig.showLog);
        _clients[config.name] = dio;
      }

      _isInitialized = true;
      if (logConfig.showLog) {
        FastLog.i(
          '✅ ApiClientPlus initialized with ${configs.length} domains',
          tag: 'INIT',
        );
      }
    } catch (e, st) {
      if (logConfig.showLog) {
        FastLog.e('❌ Failed to initialize ApiClientPlus: $e', tag: 'INIT');
        FastLog.d(st.toString(), tag: 'STACK');
      }
      rethrow;
    }
  }

  Dio _createDioClient(ApiConfig config) {
    return Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?config.defaultHeaders,
        },
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  // =================== ENHANCED API METHODS WITH CACHING ===================

  /// GET request with automatic caching
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    String? domain,
    bool useCache = true,
    Duration? cacheTtl,
  }) async {
    _ensureInitialized();

    final client = _getClientForPath(path);
    final route = _getRouteForPath(path);
    final fullPath = route?.pattern ?? path;

    // Try cache first if enabled
    if (useCache && _cacheConfig.enableCache) {
      final cacheKey = buildCacheKey(fullPath, query: query);
      final cachedData = await getCachedResponse(cacheKey);
      if (cachedData != null) {
        if (_logConfig.showLog) {
          FastLog.i('💾 Serving from cache: $cacheKey', tag: 'CACHE');
        }
        return Response<T>(
          requestOptions: RequestOptions(path: fullPath),
          data: cachedData,
          statusCode: 200,
        );
      }
    }

    // Fetch from API
    final response = await client.get<T>(
      fullPath,
      queryParameters: query,
      options: Options(headers: headers),
    );

    // Cache the response if successful
    if (useCache && _cacheConfig.enableCache && response.statusCode == 200) {
      final cacheKey = buildCacheKey(fullPath, query: query);
      await cacheResponse(
        key: cacheKey,
        data: response.data,
        ttl: cacheTtl ?? _cacheConfig.defaultTtl,
      );
      if (_logConfig.showLog) {
        FastLog.i('💾 Cached response: $cacheKey', tag: 'CACHE');
      }
    }

    return response;
  }

  /// GET request that forces refresh (ignores cache)
  Future<Response<T>> getFresh<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    String? domain,
  }) {
    return get<T>(
      path,
      query: query,
      headers: headers,
      domain: domain,
      useCache: false,
    );
  }

  /// POST request (never cached by default)
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    String? domain,
  }) async {
    _ensureInitialized();

    final client = _getClientForPath(path);
    final route = _getRouteForPath(path);
    final fullPath = route?.pattern ?? path;

    final response = await client.post<T>(
      fullPath,
      data: data,
      queryParameters: query,
      options: Options(headers: headers),
    );

    // Clear related cache if this POST might affect cached GETs
    if (_cacheConfig.enableCache && _shouldClearCacheForPost(path)) {
      clearCache(pattern: _getCachePatternForPath(path));
    }

    return response;
  }

  // =================== CACHE MANAGEMENT ===================

  /// Clear cache for specific API paths
  void clearApiCache(List<String> paths) {
    for (final path in paths) {
      clearCache(pattern: _getCachePatternForPath(path));
    }
    if (_logConfig.showLog) {
      FastLog.i('🗑️ Cleared cache for ${paths.length} paths', tag: 'CACHE');
    }
  }

  /// Get detailed cache information
  Future<Map<String, dynamic>> getCacheStats() async {
    return getCacheData();
  }

  // =================== PRIVATE HELPERS ===================

  bool _shouldClearCacheForPost(String path) {
    // Define which POST operations should clear cache
    final cacheClearingPaths = ['/users', '/posts', '/products'];
    return cacheClearingPaths.any((pattern) => path.contains(pattern));
  }

  String _getCachePatternForPath(String path) {
    // Convert path to cache pattern
    return path.replaceAll('/', '_').split('?').first;
  }

  // =================== CLIENT MANAGEMENT ===================

  Dio _getClientForPath(String path) {
    final dataRoutes = List<RoutePattern>.from(_routes);

    for (final route in dataRoutes) {
      if (route.matches(path)) {
        final client = _clients[route.baseUrlName];
        if (client != null) return client;
      }
    }
    return _getDefaultClient();
  }

  Dio _getDefaultClient() {
    if (_clients.containsKey(_defaultDomain)) {
      return _clients[_defaultDomain]!;
    }
    if (_clients.isNotEmpty) {
      return _clients.values.first;
    }
    throw Exception('No API client configured');
  }

  Dio _getClientByDomain(String domain) {
    validateDomain(domain);
    return _clients[domain]!;
  }

  RoutePattern? _getRouteForPath(String path) {
    final dataRoutes = List<RoutePattern>.from(_routes);

    for (final route in dataRoutes) {
      if (route.matches(path)) {
        return route;
      }
    }
    return null;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'ApiClientPlus not initialized. Call initialize() first.');
    }
  }

  void validateDomain(String domain) {
    if (!_clients.containsKey(domain)) {
      final availableDomains = _clients.keys.toList();
      throw ArgumentError(
        'Domain "$domain" not found. Available: ${availableDomains.join(", ")}',
      );
    }
  }

  // =================== PROPERTIES ===================
  void updateRouteAuth(String path, bool requiresAuth) {
    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];

      if (route.matches(path)) {
        _routes[i] = route.copyWith(requiresAuth: requiresAuth);
        return;
      }
    }
  }

  void updateRouteHeaders(String path, Map<String, dynamic>? headers) {
    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];

      if (route.matches(path)) {
        _routes[i] = route.copyWith(customHeaders: headers);
        return;
      }
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isCacheEnabled => _cacheConfig.enableCache;
  List<RoutePattern> get routePatterns => List.unmodifiable(_routes);
  String get defaultDomain => _defaultDomain;
  Map<String, Dio> get clients => Map.unmodifiable(_clients);

  // Authentication getters
  Future<String?> Function()? get tokenGetter => _tokenGetter;
  Future<void> Function()? get onTokenInvalid => _onTokenInvalid;
  Future<void> Function(DioException error)? get onAuthError => _onAuthError;
  Future<void> Function()? get onTokenRefresh => _onTokenRefresh;
  Future<bool> Function()? get shouldRetryAuth => _shouldRetryAuth;

  // Callback getters
  Future<void> Function(RequestOptions options)? get onRequest => _onRequest;
  Future<void> Function(Response response)? get onResponse => _onResponse;
  Future<void> Function(DioException error)? get onError => _onError;

  /// Dispose resources
  Future<void> dispose() async {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
    _configs.clear();
    _routes.clear();
    _isInitialized = false;

    if (_logConfig.showLog) {
      FastLog.i('🔒 ApiClientPlus disposed', tag: 'DISPOSE');
    }
  }
}
