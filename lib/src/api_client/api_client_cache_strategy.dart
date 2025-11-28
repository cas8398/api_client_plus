enum ApiClientCacheStrategy {
  cacheOnly, // Only use cache, no network call
  cacheFirst, // Cache then network only if miss
  cacheThenNetwork, // Return cache immediately, then fetch fresh data
  networkFirst, // Try network first, fallback to cache on failure
  networkOnly, // Skip cache completely
  staleWhileRevalidate, // Return stale cache if fresh not available, refresh in background
}

// Extension for easy conversion
extension ApiClientCacheStrategyExtension on ApiClientCacheStrategy {
  String get name {
    switch (this) {
      case ApiClientCacheStrategy.cacheOnly:
        return 'cache_only';
      case ApiClientCacheStrategy.cacheFirst:
        return 'cache_first';
      case ApiClientCacheStrategy.cacheThenNetwork:
        return 'cache_then_network';
      case ApiClientCacheStrategy.networkFirst:
        return 'network_first';
      case ApiClientCacheStrategy.networkOnly:
        return 'network_only';
      case ApiClientCacheStrategy.staleWhileRevalidate:
        return 'stale_while_revalidate';
    }
  }

  String get displayName {
    switch (this) {
      case ApiClientCacheStrategy.cacheOnly:
        return 'Cache Only';
      case ApiClientCacheStrategy.cacheFirst:
        return 'Cache First';
      case ApiClientCacheStrategy.cacheThenNetwork:
        return 'Cache Then Network';
      case ApiClientCacheStrategy.networkFirst:
        return 'Network First';
      case ApiClientCacheStrategy.networkOnly:
        return 'Network Only';
      case ApiClientCacheStrategy.staleWhileRevalidate:
        return 'Stale While Revalidate';
    }
  }

  bool get shouldCheckCache {
    return this != ApiClientCacheStrategy.networkOnly;
  }

  bool get shouldMakeNetworkCall {
    return this != ApiClientCacheStrategy.cacheOnly;
  }

  bool get shouldReturnCacheImmediately {
    return this == ApiClientCacheStrategy.cacheOnly ||
        this == ApiClientCacheStrategy.cacheFirst ||
        this == ApiClientCacheStrategy.cacheThenNetwork ||
        this == ApiClientCacheStrategy.staleWhileRevalidate;
  }
}
