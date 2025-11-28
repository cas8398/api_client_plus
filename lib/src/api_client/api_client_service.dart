import 'package:dio/dio.dart';

import 'api_client_cache_strategy.dart';
import 'api_client_base.dart';

/// High-level service class for making API requests with simplified interface
///
/// This class provides static methods for common HTTP operations with
/// sensible defaults and built-in caching support. It wraps the underlying
/// [ApiClientPlus] instance with a cleaner API.
///
/// ## Features:
/// - Static methods for easy access from anywhere
/// - Built-in caching with multiple strategies
/// - Automatic authentication handling
/// - Request/response interception
/// - Cache management utilities
///
/// ## Quick Start:
/// ```dart
/// // Initialize first (usually in main.dart)
/// await ApiClientPlus().initialize(...);
///
/// // Then use anywhere in your app:
/// final news = await ApiClientService.get(
///   '/api/news',
///   useCache: true,
///   cacheStrategy: ApiClientCacheStrategy.cacheThenNetwork,
/// );
/// ```
class ApiClientService {
  static final ApiClientPlus _client = ApiClientPlus();

  /// Get the singleton [ApiClientPlus] instance
  static ApiClientPlus get instance => _client;

  /// Execute a GET request with optional caching
  ///
  /// ## Parameters:
  /// - [path]: API endpoint path (e.g., '/api/users')
  /// - [domainName]: Which configured domain to use (optional)
  /// - [query]: URL query parameters
  /// - [headers]: Additional HTTP headers
  /// - [useCache]: Whether to use caching (default: false)
  /// - [forceRefresh]: Bypass cache and force network request
  /// - [maxStale]: Maximum age of cached data to consider valid
  /// - [timeout]: Request timeout duration
  /// - [cacheStrategy]: Caching strategy to use (default: networkOnly)
  /// - [customHeaders]: Domain-specific custom headers
  ///
  /// ## Example:
  /// ```dart
  /// final response = await ApiClientService.get(
  ///   '/api/products',
  ///   query: {'category': 'electronics', 'page': 1},
  ///   useCache: true,
  ///   cacheStrategy: ApiClientCacheStrategy.cacheFirst,
  ///   maxStale: Duration(hours: 24),
  /// );
  /// ```
  static Future<Response> get(
    String path, {
    String? domainName,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool useCache = false,
    bool forceRefresh = false,
    Duration? maxStale,
    Duration? timeout,
    ApiClientCacheStrategy? cacheStrategy,
    Map<String, dynamic>? customHeaders,
  }) async {
    return _client.executeRequest(
      path,
      method: 'GET',
      domainName: domainName,
      query: query,
      headers: headers,
      useCache: useCache,
      forceRefresh: forceRefresh,
      maxStale: maxStale,
      timeout: timeout,
      cacheStrategy: cacheStrategy,
      customHeaders: customHeaders,
    );
  }

  /// Execute a POST request
  ///
  /// ## Parameters:
  /// - [path]: API endpoint path
  /// - [domainName]: Which configured domain to use
  /// - [data]: Request body data (will be JSON encoded)
  /// - [query]: URL query parameters
  /// - [headers]: Additional HTTP headers
  /// - [requiresAuth]: Whether this endpoint requires authentication
  /// - [timeout]: Request timeout duration
  /// - [customHeaders]: Domain-specific custom headers
  ///
  /// ## Example:
  /// ```dart
  /// final response = await ApiClientService.post(
  ///   '/api/users',
  ///   data: {'name': 'John', 'email': 'john@example.com'},
  ///   requiresAuth: true,
  /// );
  /// ```
  static Future<Response> post(
    String path, {
    String? domainName,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool requiresAuth = false,
    Duration? timeout,
    Map<String, dynamic>? customHeaders,
  }) async {
    return _client.executeRequest(
      path,
      method: 'POST',
      domainName: domainName,
      data: data,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      timeout: timeout,
      customHeaders: customHeaders,
    );
  }

  /// Execute a PUT request
  ///
  /// Use for updating entire resources.
  static Future<Response> put(
    String path, {
    String? domainName,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool requiresAuth = false,
    Duration? timeout,
    Map<String, dynamic>? customHeaders,
  }) async {
    return _client.executeRequest(
      path,
      method: 'PUT',
      domainName: domainName,
      data: data,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      timeout: timeout,
      customHeaders: customHeaders,
    );
  }

  /// Execute a DELETE request
  static Future<Response> delete(
    String path, {
    String? domainName,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool requiresAuth = false,
    Duration? timeout,
    Map<String, dynamic>? customHeaders,
  }) async {
    return _client.executeRequest(
      path,
      method: 'DELETE',
      domainName: domainName,
      data: data,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      timeout: timeout,
      customHeaders: customHeaders,
    );
  }

  /// Execute a PATCH request
  ///
  /// Use for partial updates to resources.
  static Future<Response> patch(
    String path, {
    String? domainName,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool requiresAuth = false,
    Duration? timeout,
    Map<String, dynamic>? customHeaders,
  }) async {
    return _client.executeRequest(
      path,
      method: 'PATCH',
      domainName: domainName,
      data: data,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      timeout: timeout,
      customHeaders: customHeaders,
    );
  }

  /// Clear cache for a specific domain
  ///
  /// ## Example:
  /// ```dart
  /// // Clear all cache for 'api' domain
  /// await ApiClientService.clearDomainCache('api');
  /// ```
  static Future<int> clearDomainCache(String domain) async {
    return _client.clearCache(pattern: domain);
  }

  /// Clear cache for a specific HTTP method
  ///
  /// ## Example:
  /// ```dart
  /// // Clear all GET request cache
  /// await ApiClientService.clearMethodCache('GET');
  /// ```
  static Future<int> clearMethodCache(String method) async {
    return _client.clearCache(pattern: '${method}_');
  }

  /// Clear only expired cache entries
  ///
  /// Useful for periodic cleanup without removing valid cache.
  static Future<int> clearExpiredCache() async {
    return _client.clearExpiredCache();
  }

  /// Clear all cached data
  ///
  /// Use sparingly as it removes all cached API responses.
  static Future<int> clearAllCache() async {
    return _client.clearAllCache();
  }

  /// Get cache statistics for monitoring and UI display
  ///
  /// Returns cache hit rates, sizes, and other metrics.
  static Future<Map<String, dynamic>> getCacheStats() async {
    final data = await _client.getCacheData();
    return data;
  }
}
