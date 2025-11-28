import 'package:flutter_test/flutter_test.dart';
import 'package:api_client_plus/src/models/api_config.dart';
import 'package:api_client_plus/src/models/cache_config.dart';
import 'package:api_client_plus/src/models/log_config.dart';
import 'package:api_client_plus/src/models/request_options.dart';

void main() {
  group('Model Constructor Tests', () {
    test('ApiConfig default values', () {
      const config = ApiConfig(
        name: 'test',
        baseUrl: 'https://test.com',
      );

      expect(config.name, 'test');
      expect(config.baseUrl, 'https://test.com');
      expect(config.connectTimeout, const Duration(seconds: 10));
    });

    test('LogConfig default values', () {
      const logConfig = LogConfig();

      expect(logConfig.showLog, true);
      expect(logConfig.showCacheLog, false);
      expect(logConfig.logLevel, "TRACE");
      expect(logConfig.logStyle, LogStyle.none);
      expect(logConfig.isColored, true);
      expect(logConfig.useEmoji, false);
      expect(logConfig.prettyJson, false);
      expect(logConfig.messageLimit, 300);
      expect(logConfig.showTime, true);
      expect(logConfig.showCaller, false);
    });

    test('CacheConfig default values', () {
      const cacheConfig = CacheConfig();

      expect(cacheConfig.defaultTtl, const Duration(minutes: 2));
      expect(cacheConfig.enableCache, false);
    });

    test('RequestOptions default values', () {
      const options = ApiRequestOptions();

      expect(options.useCache, false);
      expect(options.forceRefresh, false);
      expect(options.enableLogging, true);
    });
  });

  group('LogStyle Constants', () {
    test('LogStyle has correct values', () {
      expect(LogStyle.standard, 0);
      expect(LogStyle.minimal, 1);
      expect(LogStyle.none, 2);
      expect(LogStyle.colored, 3);
    });

    test('LogConfig uses LogStyle.minimal as default', () {
      const logConfig = LogConfig();
      expect(logConfig.logStyle, LogStyle.none);
      expect(logConfig.logStyle, 2);
    });
  });
}
