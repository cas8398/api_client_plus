enum PluginGrade { A, B, C, F }

class PerformanceMetrics {
  final int coldStartMs;
  final int avgCacheReadMs;
  final int avgCacheWriteMs;
  final int avgRequestMs;
  final double throughput;
  final int avgErrorRecoveryMs;
  final int avgDomainSwitchMs;
  final double cacheSpeedupPercent;

  const PerformanceMetrics({
    required this.coldStartMs,
    required this.avgCacheReadMs,
    required this.avgCacheWriteMs,
    required this.avgRequestMs,
    required this.throughput,
    required this.avgErrorRecoveryMs,
    required this.avgDomainSwitchMs,
    required this.cacheSpeedupPercent,
  });

  Map<String, dynamic> toJson() {
    return {
      'coldStartMs': coldStartMs,
      'avgCacheReadMs': avgCacheReadMs,
      'avgCacheWriteMs': avgCacheWriteMs,
      'avgRequestMs': avgRequestMs,
      'throughput': throughput,
      'avgErrorRecoveryMs': avgErrorRecoveryMs,
      'avgDomainSwitchMs': avgDomainSwitchMs,
      'cacheSpeedupPercent': cacheSpeedupPercent,
    };
  }
}

class PerformanceGrader {
  static PluginGrade gradePerformance(PerformanceMetrics metrics) {
    int score = 0;

    // Cold Start (Max: 2 points)
    if (metrics.coldStartMs < 100)
      score += 2;
    else if (metrics.coldStartMs < 300) score += 1;

    if (metrics.avgCacheReadMs < 100)
      score += 2;
    else if (metrics.avgCacheReadMs < 150) score += 1;

    if (metrics.avgCacheWriteMs < 200) score += 1;

    if (metrics.avgRequestMs < 500 && metrics.throughput > 5.0)
      score += 2;
    else if (metrics.avgRequestMs < 1000 && metrics.throughput > 2.0)
      score += 1;

    if (metrics.avgErrorRecoveryMs < 500) score += 1;

    if (metrics.avgDomainSwitchMs < 150) score += 1;

    if (metrics.cacheSpeedupPercent > 20.0) score += 1;

    // Grading
    if (score >= 8) return PluginGrade.A;
    if (score >= 6) return PluginGrade.B;
    if (score >= 4) return PluginGrade.C;
    return PluginGrade.F;
  }

  static String getGradeDescription(PluginGrade grade) {
    switch (grade) {
      case PluginGrade.A:
        return 'Excellent - Production ready with outstanding performance';
      case PluginGrade.B:
        return 'Good - Production ready with solid performance';
      case PluginGrade.C:
        return 'Acceptable - Production ready but could be optimized';
      case PluginGrade.F:
        return 'Needs improvement - Not ready for production';
    }
  }

  static Map<String, String> getPerformanceTips(PerformanceMetrics metrics) {
    final tips = <String, String>{};

    if (metrics.coldStartMs >= 300) {
      tips['coldStart'] = 'Consider lazy initialization for faster startup';
    }

    if (metrics.avgCacheReadMs >= 150) {
      tips['cacheRead'] = 'Optimize cache storage or reduce cache size';
    }

    if (metrics.avgCacheWriteMs >= 200) {
      tips['cacheWrite'] = 'Consider background cache writing';
    }

    if (metrics.avgRequestMs >= 1000) {
      tips['requests'] = 'Implement request batching or connection pooling';
    }

    if (metrics.throughput <= 2.0) {
      tips['throughput'] = 'Increase concurrent request limits';
    }

    if (metrics.avgDomainSwitchMs >= 100) {
      tips['domainSwitching'] = 'Pre-warm domain connections';
    }

    if (metrics.cacheSpeedupPercent < 20.0) {
      tips['cacheEfficiency'] = 'Review cache strategy and TTL settings';
    }

    return tips;
  }
}
