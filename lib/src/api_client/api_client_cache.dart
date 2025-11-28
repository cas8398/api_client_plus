// api_client_cache.dart
import 'dart:convert';
import 'package:mmkv/mmkv.dart';

mixin ApiClientCache {
  static const String _prefix = 'api_client_plus_cache_';
  static const Duration _defaultTtl = Duration(hours: 1);

  // This will be implemented by the main class
  String get cacheInstanceName;

  // Lazy-loaded MMKV instance
  MMKV get _mmkv => MMKV(cacheInstanceName);

  /// Cache API response with enhanced metadata
  Future<void> cacheResponse({
    required String key,
    required dynamic data,
    Duration? ttl,
    String? priority,
    Map<String, dynamic>? headers,
    int? statusCode,
  }) async {
    try {
      final cacheEntry = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': (ttl ?? _defaultTtl).inMilliseconds,
        'priority': priority ?? 'normal',
        'headers': headers,
        'status_code': statusCode ?? 200,
        'expires_at':
            DateTime.now().add(ttl ?? _defaultTtl).millisecondsSinceEpoch,
      };

      final encoded = json.encode(cacheEntry);
      final success = _mmkv.encodeString('$_prefix$key', encoded);

      if (!success) {
        throw Exception('Failed to write cache entry for key: $key');
      }
    } catch (e) {
      throw Exception('Cache write error for key $key: $e');
    }
  }

  /// Get cached response with enhanced validation
  Future<dynamic> getCachedResponse(String key) async {
    try {
      final cached = _mmkv.decodeString('$_prefix$key');
      if (cached == null) return null;

      final entry = json.decode(cached) as Map<String, dynamic>;
      final timestamp = entry['timestamp'] as int?;
      final ttl = entry['ttl'] as int?;

      // Validate cache entry structure
      if (timestamp == null || ttl == null || !entry.containsKey('data')) {
        _mmkv.removeValue('$_prefix$key');
        return null;
      }

      // Check if expired using both TTL and absolute expiry
      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpiredByTtl = now - timestamp > ttl;
      final expiresAt = entry['expires_at'] as int?;
      final isExpiredByAbsolute = expiresAt != null && now > expiresAt;

      if (isExpiredByTtl || isExpiredByAbsolute) {
        _mmkv.removeValue('$_prefix$key');
        return null;
      }

      return entry['data'];
    } catch (e) {
      // Remove corrupted cache entry
      _mmkv.removeValue('$_prefix$key');
      return null;
    }
  }

  /// Get cached response with full metadata
  Future<Map<String, dynamic>?> getCachedResponseWithMetadata(
      String key) async {
    try {
      final cached = _mmkv.decodeString('$_prefix$key');
      if (cached == null) return null;

      final entry = json.decode(cached) as Map<String, dynamic>;
      final timestamp = entry['timestamp'] as int?;
      final ttl = entry['ttl'] as int?;

      if (timestamp == null || ttl == null || !entry.containsKey('data')) {
        _mmkv.removeValue('$_prefix$key');
        return null;
      }

      // Check expiration
      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = now - timestamp > ttl;
      final expiresAt = entry['expires_at'] as int?;
      final isExpiredByAbsolute = expiresAt != null && now > expiresAt;

      if (isExpired || isExpiredByAbsolute) {
        _mmkv.removeValue('$_prefix$key');
        return null;
      }

      return {
        'data': entry['data'],
        'metadata': {
          'timestamp': timestamp,
          'ttl': ttl,
          'priority': entry['priority'],
          'headers': entry['headers'],
          'status_code': entry['status_code'],
          'expires_at': expiresAt,
          'age_ms': now - timestamp,
          'remaining_ttl_ms': ttl - (now - timestamp),
        }
      };
    } catch (e) {
      _mmkv.removeValue('$_prefix$key');
      return null;
    }
  }

  /// Clear cache by pattern with enhanced matching
  Future<int> clearCache({String? pattern, bool exactMatch = false}) async {
    final allKeys = _mmkv.allKeys;
    var removedCount = 0;

    for (final key in allKeys) {
      if (!key.startsWith(_prefix)) continue;

      final cacheKey = key.substring(_prefix.length);

      bool shouldRemove = false;

      if (pattern == null) {
        shouldRemove = true;
      } else if (exactMatch) {
        shouldRemove = cacheKey == pattern;
      } else {
        shouldRemove = cacheKey.contains(pattern);
      }

      if (shouldRemove) {
        _mmkv.removeValue(key);
        removedCount++;
      }
    }

    return removedCount;
  }

  /// Clear expired cache entries
  Future<int> clearExpiredCache() async {
    final allKeys = _mmkv.allKeys;
    var expiredCount = 0;

    for (final key in allKeys) {
      if (!key.startsWith(_prefix)) continue;

      try {
        final cached = _mmkv.decodeString(key);
        if (cached == null) {
          _mmkv.removeValue(key);
          expiredCount++;
          continue;
        }

        final entry = json.decode(cached) as Map<String, dynamic>;
        final timestamp = entry['timestamp'] as int?;
        final ttl = entry['ttl'] as int?;

        if (timestamp == null || ttl == null) {
          _mmkv.removeValue(key);
          expiredCount++;
          continue;
        }

        final isExpired =
            DateTime.now().millisecondsSinceEpoch - timestamp > ttl;
        if (isExpired) {
          _mmkv.removeValue(key);
          expiredCount++;
        }
      } catch (e) {
        // Remove corrupted entries
        _mmkv.removeValue(key);
        expiredCount++;
      }
    }

    return expiredCount;
  }

  /// Clear all cache with confirmation
  Future<int> clearAllCache() async {
    final allKeys = _mmkv.allKeys;
    var removedCount = 0;

    for (final key in allKeys) {
      if (key.startsWith(_prefix)) {
        _mmkv.removeValue(key);
        removedCount++;
      }
    }

    return removedCount;
  }

  /// Get detailed cache information
  Map<String, dynamic> getCacheInfo() {
    final allKeys = _mmkv.allKeys;
    final cacheKeys = allKeys.where((key) => key.startsWith(_prefix)).toList();

    return {
      'total_entries': cacheKeys.length,
      'keys':
          cacheKeys.map((k) => k.substring(_prefix.length)).take(10).toList(),
      'instance_name': cacheInstanceName,
    };
  }

  /// Get comprehensive cache statistics
  Future<Map<String, dynamic>> getCacheData() async {
    final allKeys = _mmkv.allKeys;
    final cacheKeys = allKeys.where((key) => key.startsWith(_prefix));

    var totalSize = 0;
    var expiredCount = 0;
    var validCount = 0;
    var corruptedCount = 0;
    final priorities = <String, int>{};
    final statusCodes = <int, int>{};

    for (final key in cacheKeys) {
      try {
        final cached = _mmkv.decodeString(key);
        if (cached == null) {
          corruptedCount++;
          continue;
        }

        totalSize += cached.length;

        final entry = json.decode(cached) as Map<String, dynamic>;
        final timestamp = entry['timestamp'] as int?;
        final ttl = entry['ttl'] as int?;

        // Check if entry is valid
        if (timestamp == null || ttl == null || !entry.containsKey('data')) {
          corruptedCount++;
          continue;
        }

        // Check expiration
        final isExpired =
            DateTime.now().millisecondsSinceEpoch - timestamp > ttl;
        if (isExpired) {
          expiredCount++;
        } else {
          validCount++;
        }

        // Track priorities
        final priority = entry['priority'] as String? ?? 'unknown';
        priorities[priority] = (priorities[priority] ?? 0) + 1;

        // Track status codes
        final statusCode = entry['status_code'] as int? ?? 200;
        statusCodes[statusCode] = (statusCodes[statusCode] ?? 0) + 1;
      } catch (_) {
        corruptedCount++;
      }
    }

    final info = getCacheInfo();

    return {
      ...info,
      'total_entries': cacheKeys.length,
      'valid_entries': validCount,
      'expired_entries': expiredCount,
      'corrupted_entries': corruptedCount,
      'total_size_bytes': totalSize,
      'total_size_kb': (totalSize / 1024).toStringAsFixed(2),
      'total_size_mb': (totalSize / 1024 / 1024).toStringAsFixed(2),
      'priorities': priorities,
      'status_codes': statusCodes,
      'average_entry_size_bytes':
          cacheKeys.isNotEmpty ? (totalSize / cacheKeys.length).round() : 0,
    };
  }

  /// Check if a key exists in cache (without loading data)
  Future<bool> hasCachedResponse(String key) async {
    try {
      final cached = _mmkv.decodeString('$_prefix$key');
      if (cached == null) return false;

      final entry = json.decode(cached) as Map<String, dynamic>;
      final timestamp = entry['timestamp'] as int?;
      final ttl = entry['ttl'] as int?;

      if (timestamp == null || ttl == null) return false;

      return DateTime.now().millisecondsSinceEpoch - timestamp <= ttl;
    } catch (e) {
      return false;
    }
  }

  /// Get TTL remaining for a cached item in milliseconds
  Future<int?> getRemainingTtl(String key) async {
    try {
      final cached = _mmkv.decodeString('$_prefix$key');
      if (cached == null) return null;

      final entry = json.decode(cached) as Map<String, dynamic>;
      final timestamp = entry['timestamp'] as int?;
      final ttl = entry['ttl'] as int?;

      if (timestamp == null || ttl == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      final remaining = ttl - age;

      return remaining > 0 ? remaining : 0;
    } catch (e) {
      return null;
    }
  }

  /// Preload cache with multiple entries
  Future<void> preloadCache(Map<String, dynamic> entries,
      {Duration? ttl}) async {
    for (final entry in entries.entries) {
      await cacheResponse(
        key: entry.key,
        data: entry.value,
        ttl: ttl,
      );
    }
  }

  /// Build cache key from request details with enhanced normalization
  String buildCacheKey(String path,
      {Map<String, dynamic>? query, Map<String, dynamic>? headers}) {
    // Normalize path
    final normalizedPath = path.replaceAll(RegExp(r'/+'), '/').trim();

    // Build query string (sorted for consistency)
    String queryString = '';
    if (query != null && query.isNotEmpty) {
      final sortedQuery = Map.fromEntries(
          query.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      queryString =
          '?${Uri(queryParameters: sortedQuery.map((k, v) => MapEntry(k, v.toString()))).query}';
    }

    // Include relevant headers in cache key if needed
    String headerHash = '';
    if (headers != null && headers.isNotEmpty) {
      final relevantHeaders = {
        'authorization': headers['authorization'],
        'accept': headers['accept'],
        'content-type': headers['content-type'],
      }.map((k, v) => MapEntry(k, v?.toString() ?? ''));

      if (relevantHeaders.isNotEmpty) {
        headerHash = '|${json.encode(relevantHeaders)}'.hashCode.toString();
      }
    }

    return '${normalizedPath.replaceAll('/', '_')}$queryString$headerHash';
  }

  /// Get cache keys matching pattern
  List<String> getCacheKeys({String? pattern}) {
    final allKeys = _mmkv.allKeys;
    final cacheKeys = allKeys.where((key) => key.startsWith(_prefix)).toList();

    if (pattern == null) {
      return cacheKeys.map((k) => k.substring(_prefix.length)).toList();
    }

    return cacheKeys
        .map((k) => k.substring(_prefix.length))
        .where((key) => key.contains(pattern))
        .toList();
  }
}
