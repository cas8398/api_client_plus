class ApiRequestOptions {
  final Map<String, dynamic>? query;
  final dynamic data;
  final Map<String, dynamic>? headers;
  final bool useCache;
  final bool forceRefresh;
  final bool enableLogging;
  final Map<String, dynamic>? extra;

  const ApiRequestOptions({
    this.query,
    this.data,
    this.headers,
    this.useCache = false,
    this.forceRefresh = false,
    this.enableLogging = true,
    this.extra,
  });

  ApiRequestOptions copyWith({
    Map<String, dynamic>? query,
    dynamic data,
    Map<String, dynamic>? headers,
    bool? useCache,
    bool? forceRefresh,
    Duration? timeout,
    bool? enableLogging,
    Map<String, dynamic>? extra,
  }) {
    return ApiRequestOptions(
      query: query ?? this.query,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      useCache: useCache ?? this.useCache,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      enableLogging: enableLogging ?? this.enableLogging,
      extra: extra ?? this.extra,
    );
  }
}
