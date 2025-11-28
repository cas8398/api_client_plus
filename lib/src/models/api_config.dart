class ApiConfig {
  final String name;
  final String baseUrl;
  final Map<String, String>? defaultHeaders;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final bool requiresAuth;
  final bool verboseLogging;
  final int maxRetries;
  final Map<String, dynamic>? extra;

  const ApiConfig({
    required this.name,
    required this.baseUrl,
    this.defaultHeaders,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 10),
    this.sendTimeout = const Duration(seconds: 10),
    this.requiresAuth = false,
    this.verboseLogging = false,
    this.maxRetries = 3,
    this.extra,
  });

  ApiConfig copyWith({
    String? name,
    String? baseUrl,
    Map<String, String>? defaultHeaders,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    bool? verboseLogging,
    bool? requiresAuth,
    int? maxRetries,
    List<int>? retryStatusCodes,
    Map<String, dynamic>? extra,
  }) {
    return ApiConfig(
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      verboseLogging: verboseLogging ?? this.verboseLogging,
      maxRetries: maxRetries ?? this.maxRetries,
      extra: extra ?? this.extra,
    );
  }
}
