/// Defines different caching strategies for API requests
///
/// These strategies control how the client balances between cached data
/// and fresh network data, providing flexibility for different use cases.
///
/// ## Strategies Overview:
/// - [cacheOnly]: Offline-first, fails if no cached data available
/// - [cacheFirst]: Performance-first, uses cache when available
/// - [cacheThenNetwork]: UX-first, instant UI with background updates
/// - [networkFirst]: Data-freshness-first, falls back to cache
/// - [networkOnly]: Always fresh data, no caching
/// - [staleWhileRevalidate]: Balanced approach for frequently updated data
///
/// ## Usage Examples:
/// ```dart
/// // For offline support (settings, user profile)
/// ApiClientCacheStrategy.cacheOnly
///
/// // For static content (product catalog, categories)
/// ApiClientCacheStrategy.cacheFirst
///
/// // For social feeds, news (fast UI + fresh data)
/// ApiClientCacheStrategy.cacheThenNetwork
///
/// // For real-time data (stock prices, live scores)
/// ApiClientCacheStrategy.networkFirst
///
/// // For critical operations (payments, orders)
/// ApiClientCacheStrategy.networkOnly
///
/// // For frequently updated data (notifications, messages)
/// ApiClientCacheStrategy.staleWhileRevalidate
/// ```
enum ApiClientCacheStrategy {
  /// Only use cached data, never make network requests
  ///
  /// **Behavior**: Returns cached data if available, throws error if no cache
  /// **Use Case**: Offline-only mode, critical offline functionality
  /// **Example**: User profile, app settings, offline articles
  cacheOnly,

  /// Check cache first, only call network if cache is missing
  ///
  /// **Behavior**: Cache hit → return cache, Cache miss → network → cache → return
  /// **Use Case**: Static content, product catalog, categories
  /// **Example**: Product list, category tree, static pages
  cacheFirst,

  /// Return cached data immediately, then fetch fresh data in background
  ///
  /// **Behavior**: Cache hit → return cache immediately + background network → update cache
  /// Cache miss → network → cache → return
  /// **Use Case**: Social feeds, news, any data where UI responsiveness is critical
  /// **Example**: News feed, social media timeline, activity stream
  cacheThenNetwork,

  /// Try network first, fall back to cache only if network fails
  ///
  /// **Behavior**: Network → success → cache → return, Network → failure → cache → return
  /// **Use Case**: Data that should be fresh but can tolerate stale data on failure
  /// **Example**: Live scores, weather data, stock prices
  networkFirst,

  /// Skip cache completely, always make network requests
  ///
  /// **Behavior**: Always makes network call, never checks or updates cache
  /// **Use Case**: Critical operations, sensitive data, real-time commands
  /// **Example**: Payments, form submissions, delete operations
  networkOnly,

  /// Return stale cache immediately if fresh data not available, refresh in background
  ///
  /// **Behavior**: If cache is fresh → return cache, If cache is stale → return stale cache + background refresh
  /// **Use Case**: Frequently updated data where some staleness is acceptable
  /// **Example**: Notifications, messages, user activity
  staleWhileRevalidate,
}

/// Extension methods for [ApiClientCacheStrategy]
///
/// Provides convenient getters and helper methods for cache strategies
extension ApiClientCacheStrategyExtension on ApiClientCacheStrategy {
  /// Serialized name for API and storage (snake_case)
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

  /// Human-readable display name for UI (Title Case)
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

  /// Whether this strategy should check cache before making requests
  ///
  /// Returns `false` only for [ApiClientCacheStrategy.networkOnly]
  bool get shouldCheckCache {
    return this != ApiClientCacheStrategy.networkOnly;
  }

  /// Whether this strategy should make network calls
  ///
  /// Returns `false` only for [ApiClientCacheStrategy.cacheOnly]
  bool get shouldMakeNetworkCall {
    return this != ApiClientCacheStrategy.cacheOnly;
  }

  /// Whether this strategy returns cached data immediately when available
  ///
  /// Returns `true` for strategies that prioritize fast UI response
  bool get shouldReturnCacheImmediately {
    return this == ApiClientCacheStrategy.cacheOnly ||
        this == ApiClientCacheStrategy.cacheFirst ||
        this == ApiClientCacheStrategy.cacheThenNetwork ||
        this == ApiClientCacheStrategy.staleWhileRevalidate;
  }
}
