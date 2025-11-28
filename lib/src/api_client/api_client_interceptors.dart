part of 'api_client_base.dart';

// Interceptors extension
extension ApiClientInterceptors on ApiClientPlus {
  void _setupInterceptors(Dio dio, ApiConfig config, bool showLog) {
    dio.interceptors.clear();
    final interceptors = <Interceptor>[];

    interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 🚨 PREVENT LOOPS: Skip cache logic for background calls
        if (options.extra['background_refresh'] == true) {
          if (showLog) {
            FastLog.d('🔄 Background call detected - bypassing cache',
                tag: 'CACHE_BG');
          }
          handler.next(options);
          return;
        }

        final route = _getRouteForPath(options.path);

        // Extract cache settings with strategy support
        final useCache = options.extra['useCache'] == true;
        final forceRefresh = options.extra['forceRefresh'] == true;
        final cacheKey = options.extra['cacheKey'] as String?;
        final customTtl = options.extra['maxStale'] as Duration?;

        // Get cache strategy
        final strategy =
            options.extra['cache_strategy'] as ApiClientCacheStrategy? ??
                ApiClientCacheStrategy.cacheFirst;
        if (showLog) {
          FastLog.i('💾 Cache Strategy: ${strategy.name} for ${options.uri}',
              tag: 'CACHE_STRATEGY');
        }

        // Enhanced cache logic with strategy support
        if (isCacheEnabled &&
            strategy.shouldCheckCache &&
            options.method.toUpperCase() == 'GET') {
          final effectiveCacheKey =
              cacheKey ?? _buildCacheKeyFromRequest(options);

          if (!forceRefresh) {
            final cachedData = await getCachedResponse(effectiveCacheKey);

            if (cachedData != null) {
              if (showLog) {
                FastLog.i(
                  '💾 ✅ CACHE HIT: ${options.uri} | Strategy: ${strategy.name}',
                  tag: 'CACHE',
                );
              }
              // Handle different strategies when cache is FOUND
              switch (strategy) {
                case ApiClientCacheStrategy.cacheOnly:
                case ApiClientCacheStrategy.cacheFirst:
                  // Return cache and stop (both strategies behave the same on cache hit)
                  final cachedResponse = _createCachedResponse(
                    options,
                    cachedData,
                    effectiveCacheKey,
                  );

                  // Notify about cached response
                  if (_onCachedResponse != null) {
                    await _onCachedResponse!(cachedResponse);
                  } else if (_onResponse != null) {
                    // Fallback to regular onResponse callback
                    await _onResponse!(cachedResponse);
                  }

                  if (_onResponse != null) await _onResponse!(cachedResponse);
                  return handler.resolve(cachedResponse);

                case ApiClientCacheStrategy.cacheThenNetwork:
                  // Return cache immediately but continue to network in background
                  final cachedResponse = _createCachedResponse(
                    options,
                    cachedData,
                    effectiveCacheKey,
                  );

                  // Notify about cached response
                  if (_onCachedResponse != null) {
                    await _onCachedResponse!(cachedResponse);
                  } else if (_onResponse != null) {
                    // Fallback to regular onResponse callback
                    await _onResponse!(cachedResponse);
                  }

                  // Return cached response immediately!
                  handler.resolve(cachedResponse);

                  // Make background network call for fresh data
                  _makeBackgroundNetworkCall(
                      options, effectiveCacheKey, config, showLog);
                  return; // Stop here - don't continue to network!

                case ApiClientCacheStrategy.staleWhileRevalidate:
                  // Return cache immediately and refresh in background
                  final cachedResponse = _createCachedResponse(
                    options,
                    cachedData,
                    effectiveCacheKey,
                  );

                  // Notify about cached response
                  if (_onCachedResponse != null) {
                    await _onCachedResponse!(cachedResponse);
                  } else if (_onResponse != null) {
                    // Fallback to regular onResponse callback
                    await _onResponse!(cachedResponse);
                  }

                  // Return cached response immediately!
                  handler.resolve(cachedResponse);

                  // Make background network call for fresh data
                  _makeBackgroundNetworkCall(
                      options, effectiveCacheKey, config, showLog);
                  return; // Stop here - don't continue to network!

                case ApiClientCacheStrategy.networkFirst:
                  // Don't return cache, just mark that it's available for fallback
                  options.extra['fallback_cache_key'] = effectiveCacheKey;
                  break;

                case ApiClientCacheStrategy.networkOnly:
                  // Ignore cache completely - continue to network
                  break;
              }
            } else {
              // 🚨 CACHE MISS - Handle different strategies when cache is NOT FOUND
              if (showLog) {
                FastLog.i('💾 ❌ CACHE MISS: $effectiveCacheKey', tag: 'CACHE');
              }

              switch (strategy) {
                case ApiClientCacheStrategy.cacheOnly:
                  // 🚨 cache_only with cache miss - THROW ERROR immediately
                  if (showLog) {
                    FastLog.e(
                      '💾 ❌ CACHE MISS for cache_only strategy: $effectiveCacheKey',
                      tag: 'CACHE',
                    );
                  }

                  final error = DioException(
                    requestOptions: options,
                    type: DioExceptionType.unknown,
                    error:
                        'CacheOnlyError: No cached data available for offline access',
                    message:
                        'This feature requires data to be loaded first with an internet connection.',
                  );

                  if (_onError != null) await _onError!(error);
                  return handler
                      .reject(error); // 🚀 Stop here - NO NETWORK CALL!

                case ApiClientCacheStrategy.cacheFirst:
                case ApiClientCacheStrategy.cacheThenNetwork:
                case ApiClientCacheStrategy.staleWhileRevalidate:
                case ApiClientCacheStrategy.networkFirst:
                case ApiClientCacheStrategy.networkOnly:
                  // For all other strategies, continue to network call
                  break;
              }
            }
          } else {
            if (showLog) {
              FastLog.i('💾 🔄 FORCE REFRESH: $effectiveCacheKey',
                  tag: 'CACHE');
            }
          }

          // Set up caching for fresh response
          if (_cacheConfig.enableCache && strategy.shouldMakeNetworkCall) {
            options.extra['should_cache'] = _cacheConfig.enableCache;
            options.extra['cache_key'] = effectiveCacheKey;
            options.extra['cache_ttl'] = customTtl ?? _cacheConfig.defaultTtl;
            options.extra['cache_priority'] = _cacheConfig.priority;
          }
        }

        // Apply route-specific headers
        if (route?.customHeaders != null) {
          options.headers.addAll(route!.customHeaders!);
        }

        // Global request callback
        if (_onRequest != null) {
          await _onRequest!(options);
        }

        // Handle authentication
        final requiresAuth = route?.requiresAuth ?? true;

        if (requiresAuth && _tokenGetter != null) {
          await _handleAuthentication(options, config, showLog, handler);
        } else {
          if (showLog) {
            FastLog.t('🚀 [${config.name}] ${options.method} ${options.uri}',
                tag: "REQUEST");
            if (useCache) {
              FastLog.d(
                  '   Cache: ${forceRefresh ? 'Force Refresh' : 'Enabled'} | Strategy: ${strategy.name}',
                  tag: "CACHE");
            }
          }
          handler.next(options);
        }
      },
      onResponse: (response, handler) async {
        final strategy = response.requestOptions.extra['cache_strategy']
            as ApiClientCacheStrategy?;

        // Handle background refresh for stale-while-revalidate
        if (strategy == ApiClientCacheStrategy.staleWhileRevalidate &&
            response.requestOptions.extra['background_refresh'] == true) {
          final cacheKey =
              response.requestOptions.extra['original_cache_key'] as String?;
          if (cacheKey != null && response.statusCode == 200) {
            await cacheResponse(
              key: cacheKey,
              data: response.data,
              ttl: response.requestOptions.extra['cache_ttl'] as Duration?,
            );
            if (showLog) {
              FastLog.i('💾 🔄 Background cache updated: $cacheKey',
                  tag: 'CACHE');
            }
          }
        }

        // CACHE RESPONSE if needed
        final shouldCache =
            response.requestOptions.extra['should_cache'] == true;
        final cacheKey = response.requestOptions.extra['cache_key'] as String?;
        final cacheTtl =
            response.requestOptions.extra['cache_ttl'] as Duration?;
        final cachePriority =
            response.requestOptions.extra['cache_priority'] as CachePriority?;

        if (isCacheEnabled &&
            shouldCache &&
            cacheKey != null &&
            response.statusCode == 200) {
          try {
            await cacheResponse(
              key: cacheKey,
              data: response.data,
              ttl: cacheTtl,
              priority: cachePriority?.name,
            );
            if (showLog) {
              FastLog.i('💾 CACHED: $cacheKey | Strategy: ${strategy?.name}',
                  tag: 'CACHE');
            }
            response.extra['was_cached'] = true;
            response.extra['cache_key'] = cacheKey;
            response.extra['cache_ttl'] = cacheTtl;
            response.extra['cache_priority'] = cachePriority?.name;
          } catch (e) {
            if (showLog) {
              FastLog.e('❌ Cache save failed: $e', tag: 'CACHE');
            }
          }
        }

        // Enhanced response logging
        final fromCache = response.extra['from_cache'] == true;
        if (showLog) {
          if (fromCache) {
            FastLog.i('✅ CACHE RESPONSE: ${response.requestOptions.uri}');
          } else {
            FastLog.i(
                '🌐 NETWORK RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
            if (response.extra['was_cached'] == true) {
              FastLog.i('💾 Response was cached for future requests',
                  tag: 'CACHE');
            }
          }
        }

        // Check for force logout in response
        _checkForceLogout(response, showLog);

        // Global response callback
        if (_onResponse != null) await _onResponse!(response);
        handler.next(response);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        final useCache = error.requestOptions.extra['useCache'] == true;
        final strategy = error.requestOptions.extra['cache_strategy']
            as ApiClientCacheStrategy?;

        if (showLog) {
          FastLog.e(
              '🚨 API Error: ${error.requestOptions.uri} - ${error.message}');
          if (error.response != null) {
            FastLog.d('   Status: ${error.response?.statusCode}');
            FastLog.d('   Data: ${error.response?.data}');
          }
        }

        // Check if this was a cached response that failed
        final fromCache = error.response?.extra['from_cache'] == true;
        if (fromCache) {
          if (showLog) {
            FastLog.w(
                '⚠️ Error from cached response: ${error.requestOptions.uri}');
          }
          // Clear corrupted cache entry
          final cacheKey = error.response?.extra['cache_key'] as String?;
          if (cacheKey != null) {
            clearCache(pattern: cacheKey);

            if (showLog) {
              FastLog.i('🗑️ Cleared corrupted cache: $cacheKey', tag: 'CACHE');
            }
          }
        }

        // Handle cache fallback for network errors (only for strategies that allow fallback)
        if (useCache &&
            strategy != ApiClientCacheStrategy.networkOnly &&
            _cacheConfig.hitCacheOnNetworkFailure &&
            error.type == DioExceptionType.connectionError) {
          final cacheKey =
              error.requestOptions.extra['fallback_cache_key'] as String? ??
                  error.requestOptions.extra['cacheKey'] as String? ??
                  _buildCacheKeyFromRequest(error.requestOptions);

          final cachedData = await getCachedResponse(cacheKey);
          if (cachedData != null) {
            if (showLog) {
              FastLog.i(
                  '💾 🛡️ CACHE FALLBACK on network error: $cacheKey | Strategy: ${strategy?.name}',
                  tag: 'CACHE');
            }

            final cachedResponse = Response(
              requestOptions: error.requestOptions,
              data: cachedData,
              statusCode: 200,
              statusMessage: 'OK (from cache - network fallback)',
              extra: {
                'from_cache': true,
                'cache_key': cacheKey,
                'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
                'cache_info': {
                  'from_cache': true,
                  'cache_key': cacheKey,
                  'response_source': 'cache_fallback',
                  'network_error': error.message,
                  'strategy': strategy?.name,
                },
              },
            );

            if (_onResponse != null) await _onResponse!(cachedResponse);
            return handler.resolve(cachedResponse);
          }
        }

        // Handle cache fallback for specific error codes
        if (useCache &&
            strategy != ApiClientCacheStrategy.networkOnly &&
            error.response != null &&
            _cacheConfig.hitCacheOnErrorCodes
                .contains(error.response!.statusCode)) {
          final cacheKey =
              error.requestOptions.extra['fallback_cache_key'] as String? ??
                  error.requestOptions.extra['cacheKey'] as String? ??
                  _buildCacheKeyFromRequest(error.requestOptions);

          final cachedData = await getCachedResponse(cacheKey);
          if (cachedData != null) {
            if (showLog) {
              FastLog.i(
                  '💾 🛡️ CACHE FALLBACK on error ${error.response!.statusCode}: $cacheKey | Strategy: ${strategy?.name}',
                  tag: 'CACHE');
            }

            final cachedResponse = Response(
              requestOptions: error.requestOptions,
              data: cachedData,
              statusCode: 200,
              statusMessage: 'OK (from cache - error fallback)',
              extra: {
                'from_cache': true,
                'cache_key': cacheKey,
                'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
                'cache_info': {
                  'from_cache': true,
                  'cache_key': cacheKey,
                  'response_source': 'cache_fallback',
                  'original_status_code': error.response!.statusCode,
                  'strategy': strategy?.name,
                },
              },
            );

            if (_onResponse != null) await _onResponse!(cachedResponse);
            return handler.resolve(cachedResponse);
          }
        }

        // Global error callback
        if (_onError != null) await _onError!(error);

        // Handle auth errors
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          await _handleAuthError(error, handler, showLog);
        } else {
          handler.next(error);
        }
      },
    ));

    // Optional: Logging interceptor for detailed network traffic
    if (config.verboseLogging) {
      interceptors.add(LogInterceptor(
        request: config.verboseLogging,
        requestHeader: config.verboseLogging,
        requestBody: config.verboseLogging,
        responseHeader: config.verboseLogging,
        responseBody: config.verboseLogging,
      ));
    }

    // Add retry interceptor
    interceptors
        .add(RetryInterceptor(dio: dio, config: config, showLog: showLog));

    dio.interceptors.addAll(interceptors);

    // Log interceptor order for debugging
    if (config.verboseLogging) {
      if (showLog) {
        for (var i = 0; i < interceptors.length; i++) {
          final interceptor = interceptors[i];
          FastLog.d('   ${i + 1}. ${interceptor.runtimeType}',
              tag: 'INTERCEPTORS');
        }
      }
    }
  }

  /// Make background network call for cache-then-network strategies
  void _makeBackgroundNetworkCall(
      RequestOptions options, String cacheKey, ApiConfig config, bool showLog) {
    Future(() async {
      try {
        if (showLog) {
          FastLog.i('🔄 Making background network call: $cacheKey',
              tag: 'CACHE_BG');
        }

        final client = _getClientForPath(options.path);

        // Create background-specific options that prevent loops
        final backgroundOptions = options.copyWith(
          extra: {
            ...options.extra,
            'background_refresh': true, // Mark as background call
            'useCache': false, // Disable cache checking
            'should_cache': false, // Disable cache saving
          },
        );

        final response = await client.fetch(backgroundOptions);

        if (response.statusCode == 200) {
          // Manually update cache (bypassing the interceptor)
          await cacheResponse(
            key: cacheKey,
            data: response.data,
            ttl: options.extra['cache_ttl'] as Duration?,
          );

          if (showLog) {
            FastLog.i('💾 🔄 Background cache updated: $cacheKey',
                tag: 'CACHE_BG');
          }
        }
      } catch (e) {
        if (showLog) {
          FastLog.w('⚠️ Background refresh failed for $cacheKey: $e',
              tag: 'CACHE_BG');
        }
      }
    });
  }

  /// Helper method to create cached response
  Response _createCachedResponse(
      RequestOptions options, dynamic data, String cacheKey) {
    return Response(
      requestOptions: options,
      data: data,
      statusCode: 200,
      statusMessage: 'OK (from cache)',
      extra: {
        'from_cache': true,
        'cache_key': cacheKey,
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
        'cache_info': {
          'from_cache': true,
          'cache_key': cacheKey,
          'response_source': 'cache',
          'cache_priority': _cacheConfig.priority.name,
        },
      },
    );
  }

  String _buildCacheKeyFromRequest(RequestOptions options) {
    final method = options.method.toUpperCase();
    final path = options.uri.path;
    final query = options.uri.queryParameters;
    final domain = options.uri.host;

    // Build consistent cache key
    final queryString = query.isNotEmpty
        ? '?${Uri(queryParameters: query.map((k, v) => MapEntry(k, v.toString()))).query}'
        : '';

    return '${method}_${domain}_${path}_${_generateHash(queryString)}';
  }

  String _generateHash(String input) {
    return input.hashCode.toRadixString(16);
  }

  Future<void> _handleAuthentication(
    RequestOptions options,
    ApiConfig config,
    bool enableLogging,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenGetter!();

      // Check if this route actually requires authentication
      final route = _getRouteForPath(options.path);
      final requiresAuth = route?.requiresAuth ?? config.requiresAuth;

      if (requiresAuth) {
        // Route requires authentication
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
          if (enableLogging) {
            FastLog.t('🚀 [${config.name}] ${options.method} ${options.uri}',
                tag: "REQUEST");
            FastLog.d(
                '   🔐 Token added: ${token.substring(0, min(10, token.length))}...',
                tag: "AUTH");
          }
          handler.next(options);
        } else {
          // No token but route requires auth
          if (enableLogging) {
            FastLog.e(
                '❌ Authentication required but no token available for ${options.uri}',
                tag: "AUTH");
          }

          final error = DioException(
            requestOptions: options,
            type: DioExceptionType.unknown,
            error: 'Authentication required for this endpoint',
          );

          if (_onAuthError != null) {
            await _onAuthError!(error);
          } else if (_onTokenInvalid != null) {
            await _onTokenInvalid!();
          }

          handler.reject(error);
        }
      } else {
        // Route doesn't require authentication - proceed without token
        if (enableLogging) {
          FastLog.t(
              '🚀 [${config.name}] ${options.method} ${options.uri} (No auth required)',
              tag: "REQUEST");
        }
        handler.next(options);
      }
    } catch (e) {
      if (enableLogging) {
        FastLog.e('❌ Token retrieval failed: $e', tag: "AUTH");
      }
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: 'Token retrieval failed: $e',
      ));
    }
  }

  Future<void> _handleAuthError(
      DioException error, ErrorInterceptorHandler handler, bool showLog) async {
    final shouldRetry = await _shouldRetryAuth?.call() ?? false;

    if (shouldRetry && _onTokenRefresh != null) {
      try {
        if (showLog) {
          FastLog.i('🔄 Attempting token refresh...', tag: "AUTH");
        }
        await _onTokenRefresh!();

        // Retry the request with new token
        final client = _getClientForPath(error.requestOptions.path);
        if (showLog) {
          FastLog.i('🔄 Retrying request with new token...', tag: "AUTH");
        }

        // Create new request options with updated token
        final newOptions = error.requestOptions.copyWith();
        final newToken = await _tokenGetter!();
        newOptions.headers["Authorization"] = "Bearer $newToken";

        final response = await client.fetch(newOptions);

        if (showLog) {
          FastLog.i('✅ Request succeeded after token refresh', tag: "AUTH");
        }
        handler.resolve(response);
        return;
      } catch (e) {
        if (showLog) {
          FastLog.e('❌ Token refresh failed: $e', tag: "AUTH");
        }
        // Refresh failed, proceed with original error
      }
    }

    // Notify auth error handlers
    if (_onAuthError != null) {
      await _onAuthError!(error);
    } else if (_onTokenInvalid != null) {
      await _onTokenInvalid!();
    }

    handler.next(error);
  }

  void _checkForceLogout(Response response, bool showLog) {
    try {
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final isForceLogout = data['logout'] == true ||
            data['force_logout'] == true ||
            data['status'] == 'force_logout';

        if (isForceLogout && _onTokenInvalid != null) {
          if (showLog) {
            FastLog.w('🔒 Force logout detected from API response',
                tag: "AUTH");
            _onTokenInvalid!();
          }
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
  }
}
