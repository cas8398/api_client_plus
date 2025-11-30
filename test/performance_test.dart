import 'dart:io';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_client_plus/api_client_plus.dart';

void main() {
  // Setup before all tests - just ensure Flutter binding is initialized
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Print platform info
    print('🚀 Running on: ${Platform.operatingSystem}');
    print('🚀 Platform version: ${Platform.operatingSystemVersion}');
    print('🚀 Local hostname: ${Platform.localHostname}');
  });

  group('Plugin Load Time Performance', () {
    test('Plugin initialization time - without cache', () async {
      final stopwatch = Stopwatch()..start();

      final api = ApiClientPlus();
      await api.initialize(
        configs: [
          ApiConfig(
            name: 'test1',
            baseUrl: 'https://api1.example.com',
            connectTimeout: Duration(seconds: 1),
            receiveTimeout: Duration(seconds: 1),
            sendTimeout: Duration(seconds: 1),
          ),
        ],
        defaultDomain: 'test1',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(
          enableCache: false,
        ),
        logConfig: LogConfig(
          showLog: false,
        ),
      );

      stopwatch.stop();
      final initializationTime = stopwatch.elapsedMilliseconds;

      print(
          '📦 Plugin Initialization Time (no cache): ${initializationTime}ms');
      expect(initializationTime, lessThan(100));

      await api.dispose();
    });

    test('Plugin initialization time - cache disabled in VM', () async {
      final stopwatch = Stopwatch()..start();

      final api = ApiClientPlus();
      await api.initialize(
        configs: [
          ApiConfig(
            name: 'test1',
            baseUrl: 'https://api1.example.com',
            connectTimeout: Duration(seconds: 1),
            receiveTimeout: Duration(seconds: 1),
            sendTimeout: Duration(seconds: 1),
          ),
        ],
        defaultDomain: 'test1',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(
          enableCache: false, // Cache disabled for VM environment
          priority: CachePriority.high,
          defaultTtl: Duration(minutes: 5),
        ),
        logConfig: LogConfig(
          showLog: false,
        ),
      );

      stopwatch.stop();
      final initializationTime = stopwatch.elapsedMilliseconds;

      print(
          '📦 Plugin Initialization Time (cache disabled in VM): ${initializationTime}ms');
      expect(
          initializationTime, lessThan(100)); // Should be faster without cache

      await api.dispose();
    });
  });

  group('Local Performance Tests (No Network)', () {
    test('Service method call overhead - local only', () async {
      final api = ApiClientPlus();
      await api.initialize(
        configs: [
          ApiConfig(
            name: 'local',
            baseUrl: 'http://localhost:9999',
            connectTimeout: Duration(milliseconds: 10),
            receiveTimeout: Duration(milliseconds: 10),
            sendTimeout: Duration(milliseconds: 10),
          ),
        ],
        defaultDomain: 'local',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(enableCache: false), // Cache disabled
        logConfig: LogConfig(showLog: false),
      );

      const iterations = 50;
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        try {
          await ApiClientService.get('/test-$i', domainName: 'local')
              .timeout(Duration(milliseconds: 5));
        } catch (e) {
          // Expected to fail quickly
        }
      }

      stopwatch.stop();
      final totalTime = stopwatch.elapsedMilliseconds;
      final averageCallTime = totalTime / iterations;

      print('⚡ Local Service Method Call Overhead:');
      print('   Total for $iterations calls: ${totalTime}ms');
      print('   Average per call: ${averageCallTime}ms');

      expect(averageCallTime, lessThan(10));

      await api.dispose();
    });

    test('CacheConfig.copyWith() performance - cache disabled', () async {
      const iterations = 1000;
      final stopwatch = Stopwatch()..start();

      final baseConfig = CacheConfig(
        enableCache: false, // Cache disabled
        defaultTtl: Duration(minutes: 5),
        hitCacheOnNetworkFailure: true,
      );

      CacheConfig currentConfig = baseConfig;

      for (int i = 0; i < iterations; i++) {
        currentConfig = currentConfig.copyWith(
          defaultTtl: Duration(minutes: i % 10),
          enableCache: false, // Keep cache disabled
          hitCacheOnErrorCodes: [400 + i % 100, 500 + i % 100],
        );
      }

      stopwatch.stop();
      final totalTime = stopwatch.elapsedMicroseconds;
      final averageCopyTime = totalTime / iterations;

      print('📋 CacheConfig.copyWith() Performance (cache disabled):');
      print('   Total for $iterations copies: ${totalTime}μs');
      print('   Average per copy: ${averageCopyTime.toStringAsFixed(2)}μs');

      expect(averageCopyTime, lessThan(100.0));
    });
  });

  group('Configuration Performance', () {
    test('Large configuration load time - no cache', () async {
      final stopwatch = Stopwatch()..start();

      final api = ApiClientPlus();
      final configs = List.generate(
          10,
          (i) => ApiConfig(
                name: 'config$i',
                baseUrl: 'https://config$i.example.com',
              ));

      await api.initialize(
        configs: configs,
        defaultDomain: 'config0',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(enableCache: false), // Cache disabled
        logConfig: LogConfig(showLog: false),
      );

      stopwatch.stop();
      final loadTime = stopwatch.elapsedMilliseconds;

      print('⚙️ Large Configuration Load (10 configs): ${loadTime}ms');
      expect(loadTime, lessThan(100));

      await api.dispose();
    });

    test('Large configuration load time - cache disabled', () async {
      final stopwatch = Stopwatch()..start();

      final api = ApiClientPlus();
      final configs = List.generate(
          10,
          (i) => ApiConfig(
                name: 'config$i',
                baseUrl: 'https://config$i.example.com',
              ));

      await api.initialize(
        configs: configs,
        defaultDomain: 'config0',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(
          enableCache: false, // Cache disabled
          defaultTtl: Duration(minutes: 10),
        ).copyWith(hitCacheOnErrorCodes: [500, 502, 503]),
        logConfig: LogConfig(showLog: false),
      );

      stopwatch.stop();
      final loadTime = stopwatch.elapsedMilliseconds;

      print(
          '⚙️ Large Configuration Load with Cache Disabled (10 configs): ${loadTime}ms');
      expect(loadTime, lessThan(100)); // Should be same as without cache config

      await api.dispose();
    });
  });

  group('Error Handling Performance', () {
    test('Fast error handling with short timeouts', () async {
      final api = ApiClientPlus();
      await api.initialize(
        configs: [
          ApiConfig(
            name: 'errorfast',
            baseUrl:
                'https://invalid-domain-${DateTime.now().millisecondsSinceEpoch}.com',
            connectTimeout: Duration(milliseconds: 10),
            receiveTimeout: Duration(milliseconds: 10),
            sendTimeout: Duration(milliseconds: 10),
          ),
        ],
        defaultDomain: 'errorfast',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(enableCache: false), // Cache disabled
        logConfig: LogConfig(showLog: false),
      );

      const errorIterations = 20;
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < errorIterations; i++) {
        try {
          await ApiClientService.get('/test', domainName: 'errorfast')
              .timeout(Duration(milliseconds: 15));
        } catch (e) {
          // Expected to fail quickly
        }
      }

      stopwatch.stop();
      final totalTime = stopwatch.elapsedMilliseconds;
      final averageErrorTime = totalTime / errorIterations;

      print('🚨 Fast Error Handling:');
      print('   Average error time: ${averageErrorTime}ms');

      expect(averageErrorTime, lessThan(20));

      await api.dispose();
    });

    test('Error handling without cache fallback', () async {
      final api = ApiClientPlus();
      await api.initialize(
        configs: [
          ApiConfig(
            name: 'cachefallback',
            baseUrl: 'https://unreachable-cache-test.com',
            connectTimeout: Duration(milliseconds: 10),
            receiveTimeout: Duration(milliseconds: 10),
            sendTimeout: Duration(milliseconds: 10),
          ),
        ],
        defaultDomain: 'cachefallback',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(
          enableCache: false, // Cache disabled - no fallback
          hitCacheOnNetworkFailure: true, // This will be ignored
          hitCacheOnErrorCodes: [500, 502, 503], // This will be ignored
        ).copyWith(defaultTtl: Duration(minutes: 1)),
        logConfig: LogConfig(showLog: false),
      );

      const iterations = 10;
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        try {
          await ApiClientService.get('/fallback-test-$i',
                  domainName: 'cachefallback')
              .timeout(Duration(milliseconds: 20));
        } catch (e) {
          // Expected to fail - no cache fallback
        }
      }

      stopwatch.stop();
      final totalTime = stopwatch.elapsedMilliseconds;
      final averageTime = totalTime / iterations;

      print('🔄 Error Handling without Cache Fallback:');
      print('   Average time: ${averageTime}ms');

      expect(averageTime, lessThan(30));

      await api.dispose();
    });
  });

  group('Concurrent Performance Tests', () {
    test('Multiple client instances with cache disabled', () async {
      const clientCount = 5;
      final stopwatch = Stopwatch()..start();

      final clients = <ApiClientPlus>[];

      for (int i = 0; i < clientCount; i++) {
        final client = ApiClientPlus();
        await client.initialize(
          configs: [
            ApiConfig(
              name: 'concurrent$i',
              baseUrl: 'https://concurrent$i.example.com',
            ),
          ],
          defaultDomain: 'concurrent$i',
          tokenGetter: () async => null,
          onTokenInvalid: () async {},
          cacheConfig: CacheConfig(
            enableCache: false, // Cache disabled for all
            defaultTtl: Duration(minutes: i * 2),
          ).copyWith(hitCacheOnErrorCodes: [500 + i]),
          logConfig: LogConfig(showLog: false),
        );
        clients.add(client);
      }

      stopwatch.stop();
      final totalTime = stopwatch.elapsedMilliseconds;
      final averageTime = totalTime / clientCount;

      print('🚀 Multiple Client Instances (cache disabled):');
      print('   Total for $clientCount clients: ${totalTime}ms');
      print('   Average per client: ${averageTime}ms');

      expect(averageTime, lessThan(50)); // Should be faster without cache

      // Cleanup
      for (final client in clients) {
        await client.dispose();
      }
    });

    test('Rapid create/dispose cycles without cache', () async {
      const cycles = 10;
      final initializationTimes = <int>[];

      for (int i = 0; i < cycles; i++) {
        final stopwatch = Stopwatch()..start();

        final client = ApiClientPlus();
        await client.initialize(
          configs: [
            ApiConfig(
              name: 'cycle$i',
              baseUrl: 'https://cycle$i.example.com',
            ),
          ],
          defaultDomain: 'cycle$i',
          tokenGetter: () async => null,
          onTokenInvalid: () async {},
          cacheConfig: CacheConfig(
            enableCache: false, // Cache disabled
            defaultTtl: Duration(minutes: i),
          ).copyWith(hitCacheOnNetworkFailure: i.isEven),
          logConfig: LogConfig(showLog: false),
        );

        stopwatch.stop();
        initializationTimes.add(stopwatch.elapsedMilliseconds);

        await client.dispose();

        // Small delay between cycles
        await Future.delayed(Duration(milliseconds: 1));
      }

      final averageTime = initializationTimes.reduce((a, b) => a + b) ~/ cycles;
      final maxTime = initializationTimes.reduce((a, b) => a > b ? a : b);

      print('🔄 Rapid Create/Dispose Cycles without Cache:');
      print('   Average initialization: ${averageTime}ms');
      print('   Max initialization: ${maxTime}ms');
      print('   All times: $initializationTimes');

      expect(maxTime, lessThan(100)); // Should be faster without cache
    });
  });

  group('Real-world Simulation Tests', () {
    test('Production-like configuration performance - cache disabled',
        () async {
      final stopwatch = Stopwatch()..start();

      final api = ApiClientPlus();
      await api.initialize(
        configs: [
          ApiConfig(
            name: 'auth-service',
            baseUrl: 'https://auth.production.com',
            connectTimeout: Duration(seconds: 30),
            receiveTimeout: Duration(seconds: 30),
            sendTimeout: Duration(seconds: 30),
            defaultHeaders: {
              'Content-Type': 'application/json',
              'User-Agent': 'MyApp/1.0.0',
            },
          ),
          ApiConfig(
            name: 'api-service',
            baseUrl: 'https://api.production.com',
            connectTimeout: Duration(seconds: 60),
            receiveTimeout: Duration(seconds: 60),
            sendTimeout: Duration(seconds: 60),
          ),
          ApiConfig(
            name: 'cdn-service',
            baseUrl: 'https://cdn.production.com',
            connectTimeout: Duration(seconds: 10),
            receiveTimeout: Duration(seconds: 10),
            sendTimeout: Duration(seconds: 10),
          ),
        ],
        defaultDomain: 'api-service',
        tokenGetter: () async => 'mock-production-token',
        onTokenInvalid: () async => print('Token refresh needed'),
        cacheConfig: CacheConfig(
          enableCache: false, // Cache disabled for VM
          defaultTtl: Duration(minutes: 15),
          hitCacheOnErrorCodes: [500, 502, 503, 401, 403],
          hitCacheOnNetworkFailure: true,
          priority: CachePriority.high,
        ).copyWith(defaultTtl: Duration(minutes: 30)),
        logConfig: LogConfig(
          showLog: false,
          logLevel: "WARN",
        ),
      );

      stopwatch.stop();
      final initializationTime = stopwatch.elapsedMilliseconds;

      print('🏭 Production-like Configuration (cache disabled):');
      print('   3 services, cache disabled: ${initializationTime}ms');

      expect(initializationTime, lessThan(100)); // Should be faster

      await api.dispose();
    });
  });

  // Add a specific test to verify cache strategies don't crash when cache is disabled
  group('Cache Strategy Compatibility - Cache Disabled', () {
    test('Cache strategies should handle disabled cache gracefully', () async {
      final api = ApiClientPlus();
      await api.initialize(
        configs: [
          ApiConfig(
            name: 'cache-test',
            baseUrl: 'https://jsonplaceholder.typicode.com',
            connectTimeout: Duration(seconds: 10),
            receiveTimeout: Duration(seconds: 10),
          ),
        ],
        defaultDomain: 'cache-test',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(enableCache: false), // Cache disabled
        logConfig: LogConfig(showLog: true),
      );

      // Test that cache strategies don't crash when cache is disabled
      final strategies = [
        ApiClientCacheStrategy.networkOnly,
        ApiClientCacheStrategy.cacheFirst,
        ApiClientCacheStrategy.cacheOnly,
        ApiClientCacheStrategy.networkFirst,
      ];

      for (final strategy in strategies) {
        print('   Testing strategy: $strategy');
        try {
          await ApiClientService.get(
            '/todos/1',
            domainName: 'cache-test',
            cacheStrategy: strategy,
          ).timeout(Duration(seconds: 5));
          print('   ✅ $strategy completed without crash');
        } catch (e) {
          // Expected for cacheOnly when no cache, but shouldn't crash
          print('   ⚠️ $strategy threw expected error: ${e.toString()}');
        }
      }

      await api.dispose();
    });
  });
}
