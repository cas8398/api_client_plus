class RoutePattern {
  final String pattern;
  final String baseUrlName;
  final bool requiresAuth;
  final Map<String, dynamic>? customHeaders;

  const RoutePattern({
    required this.pattern,
    required this.baseUrlName,
    this.requiresAuth = false,
    this.customHeaders,
  });

  bool matches(String path) {
    if (pattern == '*') return true;
    if (pattern.endsWith('*')) {
      final prefix = pattern.substring(0, pattern.length - 1);
      return path.startsWith(prefix);
    }
    return path == pattern;
  }

  RoutePattern copyWith({
    String? pattern,
    String? baseUrlName,
    bool? requiresAuth,
    Map<String, dynamic>? customHeaders,
  }) {
    return RoutePattern(
      pattern: pattern ?? this.pattern,
      baseUrlName: baseUrlName ?? this.baseUrlName,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      customHeaders: customHeaders ?? this.customHeaders,
    );
  }
}
