import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

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
}
