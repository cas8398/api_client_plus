import 'package:dio/dio.dart';

import 'api_client_cache_strategy.dart';
import 'api_client_base.dart';

/// High-level service class for making API requests
class ApiClientService {
  static final ApiClientPlus _client = ApiClientPlus();

  /// Get singleton instance
  static ApiClientPlus get instance => _client;

  /// GET request
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

  /// POST request
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

  /// PUT request
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

  /// DELETE request
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

  /// PATCH request
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

  /// Clear cache for specific domain
  static Future<int> clearDomainCache(String domain) async {
    return _client.clearCache(pattern: domain);
  }

  /// Clear cache for specific HTTP method
  static Future<int> clearMethodCache(String method) async {
    return _client.clearCache(pattern: '${method}_');
  }

  static Future<int> clearExpiredCache() async {
    return _client.clearExpiredCache();
  }

  static Future<int> clearAllCache() async {
    return _client.clearAllCache();
  }

  /// Get cache statistics for UI
  static Future<Map<String, dynamic>> getCacheStats() async {
    final data = await _client.getCacheData();
    return data;
  }
}
