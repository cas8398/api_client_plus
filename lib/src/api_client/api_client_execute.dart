part of 'api_client_base.dart';

// Request execution extension
extension ApiClientExecute on ApiClientPlus {
  /// Internal method used by ApiMethods
  Future<Response<T>> executeRequest<T>(
    String path, {
    required String method,
    String? domainName,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool useCache = false,
    bool requiresAuth = false,
    bool forceRefresh = false,
    Duration? maxStale,
    Duration? timeout,
    ApiClientCacheStrategy? cacheStrategy,
    Map<String, dynamic>? customHeaders,
  }) async {
    _ensureInitialized();
    final domain = domainName ?? _defaultDomain;

    try {
      validateDomain(domain);
      final client = _getClientByDomain(domain);

      if (requiresAuth) {
        updateRouteAuth(path, true);
      }

      if (customHeaders != null && customHeaders.isNotEmpty) {
        updateRouteHeaders(path, customHeaders);
      }

      // Determine cache strategy (backward compatible)
      final effectiveStrategy = _determineCacheStrategy(
        method: method,
        useCache: useCache,
        forceRefresh: forceRefresh,
        providedStrategy: cacheStrategy,
      );

      final requestOptions = Options(
        method: method,
        headers: headers,
        extra: {
          'useCache': useCache || false,
          'forceRefresh': forceRefresh,
          'maxStale': maxStale,
          'cache_strategy': effectiveStrategy,
          'cache_key': _buildCacheKey(path, query: query, method: method),
          ...?customHeaders,
        },
      );

      // Apply timeout if specified
      if (timeout != null) {
        client.options.connectTimeout = timeout;
      }

      if (_logConfig.showLog) {
        FastLog.i('🔍 Executing $method $path | '
            'Cache: ${effectiveStrategy.name} | '
            'Refresh: $forceRefresh');
      }

      Response<T> response;

      switch (method) {
        case 'GET':
          response = await client.get<T>(
            path,
            queryParameters: query,
            options: requestOptions,
          );
          break;
        case 'POST':
          response = await client.post<T>(
            path,
            data: data,
            queryParameters: query,
            options: requestOptions,
          );
          break;
        case 'PUT':
          response = await client.put<T>(
            path,
            data: data,
            queryParameters: query,
            options: requestOptions,
          );
          break;
        case 'DELETE':
          response = await client.delete<T>(
            path,
            data: data,
            queryParameters: query,
            options: requestOptions,
          );
          break;
        case 'PATCH':
          response = await client.patch<T>(
            path,
            data: data,
            queryParameters: query,
            options: requestOptions,
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Clear related cache for mutations that affect GET requests
      if (_cacheConfig.enableCache &&
          _shouldClearCacheForMutation(method, path)) {
        clearCache(pattern: _getCachePatternForPath(path));
      }

      return response;
    } on DioException catch (e) {
      final apiError = _wrapDioException(e, domain, path);
      _logDioError(e, apiError);
      throw apiError;
    } catch (e) {
      final apiError = ApiClientError(
          message: e.toString(),
          type: 'UNKNOWN_ERROR',
          domain: domain,
          path: path,
          responseData: 'UNKNOWN_ERROR');

      if (_logConfig.showLog) {
        FastLog.e('Unexpected error: $e', tag: "UNEXPECTED_ERROR");
      }
      throw apiError;
    }
  }

  /// Determine the effective cache strategy
  ApiClientCacheStrategy _determineCacheStrategy({
    required String method,
    required bool useCache,
    required bool forceRefresh,
    ApiClientCacheStrategy? providedStrategy,
  }) {
    // If strategy is explicitly provided, use it
    if (providedStrategy != null) {
      return providedStrategy;
    }

    // For non-GET methods, default to networkOnly
    if (method.toUpperCase() != 'GET') {
      return ApiClientCacheStrategy.networkOnly;
    }

    // Backward compatibility with useCache parameter
    if (!useCache) {
      return ApiClientCacheStrategy.networkOnly;
    }

    // If forcing refresh, use networkFirst to get fresh data but allow cache fallback
    if (forceRefresh) {
      return ApiClientCacheStrategy.networkFirst;
    }

    // Default cache strategy for GET requests with useCache: true
    return ApiClientCacheStrategy.cacheFirst;
  }

  /// Build cache key for request
  String _buildCacheKey(String path,
      {Map<String, dynamic>? query, String method = 'GET'}) {
    return buildCacheKey(path, query: query);
  }

  bool _shouldClearCacheForMutation(String method, String path) {
    // Clear cache for mutations that might affect cached GET requests
    final mutationMethods = ['POST', 'PUT', 'DELETE', 'PATCH'];

    return mutationMethods.contains(method);
  }

  void _logDioError(DioException e, ApiClientError apiError) {
    final request = e.requestOptions;

    if (_logConfig.showLog) {
      FastLog.e('🚨 ${request.method} ${request.uri} → ${apiError.type}',
          tag: "API");
      FastLog.d(
          '💥 ${apiError.message}\n🌐 ${request.baseUrl}\n📍 ${request.path}',
          tag: "API_DETAILS");
    }
  }
}
