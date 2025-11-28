import 'package:flutter_test/flutter_test.dart';
import 'package:api_client_plus/api_client_plus.dart';

void main() {
  group('ApiClientPlus Basic Tests', () {
    test('Singleton pattern works correctly', () {
      final instance1 = ApiClientPlus();
      final instance2 = ApiClientPlus();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Getters return empty lists before initialization', () {
      final api = ApiClientPlus();
      expect(api.routePatterns, isEmpty);
    });
  });

  group('Model Tests', () {
    test('ApiConfig model', () {
      const config = ApiConfig(
        name: 'test',
        baseUrl: 'https://test.com',
        connectTimeout: Duration(seconds: 10),
      );

      expect(config.name, 'test');
      expect(config.baseUrl, 'https://test.com');
      expect(config.connectTimeout, const Duration(seconds: 10));
    });

    test('ApiConfig copyWith works', () {
      const original = ApiConfig(
        name: 'original',
        baseUrl: 'https://original.com',
      );

      final copied = original.copyWith(
        name: 'copied',
        baseUrl: 'https://copied.com',
      );

      expect(copied.name, 'copied');
      expect(copied.baseUrl, 'https://copied.com');
    });

    test('LogConfig model', () {
      const logConfig = LogConfig(
        showLog: false,
        logLevel: "ERROR",
        logStyle: LogStyle.minimal,
      );

      expect(logConfig.showLog, false);
      expect(logConfig.logLevel, "ERROR");
      expect(logConfig.logStyle, LogStyle.minimal);
    });

    test('CacheConfig model', () {
      const cacheConfig = CacheConfig(
        enableCache: false,
      );

      expect(cacheConfig.enableCache, false);
    });

    test('ApiRequestOptions model', () {
      const options = ApiRequestOptions(
        useCache: true,
        forceRefresh: false,
        enableLogging: true,
      );

      expect(options.useCache, true);
      expect(options.forceRefresh, false);
      expect(options.enableLogging, true);
    });
  });

  group('LogStyle Constants', () {
    test('LogStyle constants are correct', () {
      expect(LogStyle.standard, 0);
      expect(LogStyle.minimal, 1);
      expect(LogStyle.none, 2);
      expect(LogStyle.colored, 3);
    });
  });
}
