import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';

class CacheConfig {
  final List<int> hitCacheOnErrorCodes;
  final bool hitCacheOnNetworkFailure;
  final CachePriority priority;
  final bool enableCache;
  final Duration defaultTtl;

  const CacheConfig({
    this.hitCacheOnErrorCodes = const [500, 502, 503, 401, 403],
    this.hitCacheOnNetworkFailure = true,
    this.priority = CachePriority.normal,
    this.enableCache = false,
    this.defaultTtl = const Duration(minutes: 2),
  });

  CacheConfig copyWith({
    List<int>? hitCacheOnErrorCodes,
    bool? hitCacheOnNetworkFailure,
    CachePriority? priority,
    bool? enableCache,
    Duration? defaultTtl,
  }) {
    return CacheConfig(
      hitCacheOnErrorCodes: hitCacheOnErrorCodes ?? this.hitCacheOnErrorCodes,
      hitCacheOnNetworkFailure:
          hitCacheOnNetworkFailure ?? this.hitCacheOnNetworkFailure,
      priority: priority ?? this.priority,
      enableCache: enableCache ?? this.enableCache,
      defaultTtl: defaultTtl ?? this.defaultTtl,
    );
  }

  @override
  String toString() {
    return 'CacheConfig('
        'hitCacheOnErrorCodes: $hitCacheOnErrorCodes, '
        'hitCacheOnNetworkFailure: $hitCacheOnNetworkFailure, '
        'priority: $priority, '
        'enableCache: $enableCache, '
        'defaultTtl: $defaultTtl'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CacheConfig &&
        listEquals(other.hitCacheOnErrorCodes, hitCacheOnErrorCodes) &&
        other.hitCacheOnNetworkFailure == hitCacheOnNetworkFailure &&
        other.priority == priority &&
        other.enableCache == enableCache &&
        other.defaultTtl == defaultTtl;
  }

  @override
  int get hashCode {
    return Object.hash(
      hitCacheOnErrorCodes.hashCode,
      hitCacheOnNetworkFailure,
      priority,
      enableCache,
      defaultTtl,
    );
  }
}
