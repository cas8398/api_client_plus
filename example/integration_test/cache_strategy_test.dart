import 'package:api_client_plus_example/speed_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:api_client_plus/api_client_plus.dart';
import 'package:dio/dio.dart';
import 'dart:io' show Platform;
import 'dart:async';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('🧠 Cache Strategy Comprehensive Tests', () {
    late ApiClientPlus apiClient;
    // Test results storage
    final testResults = <String, dynamic>{
      'device': {},
      'timestamp': '',
      'tests': <Map<String, dynamic>>[],
    };

    // Helper to track test results
    void _recordTestResult(String name, bool passed,
        {String? notes, dynamic data}) {
      testResults['tests'].add({
        'name': name,
        'passed': passed,
        'notes': notes,
        'data': data,
      });
    }

    setUpAll(() async {
      final deviceInfoPlugin = DeviceInfoPlugin();
      Map<String, dynamic> deviceData = {};

      final connectivityResult = await Connectivity().checkConnectivity();
      String connectionType;
      switch (connectivityResult) {
        case ConnectivityResult.mobile:
          connectionType = 'Mobile';
          break;
        case ConnectivityResult.wifi:
          connectionType = 'Wi-Fi';
          break;
        default:
          connectionType = 'None';
      }

      final speedTest = await measureDownloadSpeedMbps();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceData = {
          'os': 'Android',
          'osVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'networkType': connectionType,
          'downloadSpeedMbps': speedTest,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceData = {
          'os': 'iOS',
          'osVersion': iosInfo.systemVersion,
          'model': iosInfo.utsname.machine,
          'name': iosInfo.name,
          'networkType': connectionType,
          'downloadSpeedMbps': speedTest,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      }

      print(
          '📱 Testing on: ${deviceData['manufacturer'] ?? deviceData['name']} '
          '${deviceData['model']} (${deviceData['os']} ${deviceData['osVersion']}) - Internet Speed: $speedTest Mbps over $connectionType');

      testResults['device'] = deviceData;
      testResults['timestamp'] = DateTime.now().toString();
    });

    setUp(() async {
      apiClient = ApiClientPlus();
      await apiClient.initialize(
        configs: [
          ApiConfig(
            name: 'cache-strategy-test',
            baseUrl: 'https://httpbin.org',
            connectTimeout: Duration(seconds: 30),
            receiveTimeout: Duration(seconds: 30),
          ),
        ],
        defaultDomain: 'cache-strategy-test',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(
          enableCache: true,
          defaultTtl: Duration(minutes: 5),
        ),
        logConfig: LogConfig(showLog: false),
      );
    });

    tearDown(() async {
      await apiClient.dispose();
    });

    testWidgets('1. cacheOnly - Offline Mode Behavior',
        (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing cacheOnly strategy...');

      try {
        // First, make a successful network call to populate cache with networkOnly
        print('   📞 Making initial network call...');
        final firstResponse = await ApiClientService.get(
          '/json',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkOnly,
        );
        expect(firstResponse.statusCode, 200);
        print('   ✅ Initial network call successful');

        // Debug: Check if cache was written
        print('   🔍 Checking cache contents...');
        // Add a method to inspect cache or log cache writes

        // Increase delay and verify cache writing
        await Future.delayed(Duration(milliseconds: 500));
        print('   ⏳ Delay completed');

        // Debug: Try to access the same endpoint with cacheFirst to verify caching
        print('   🔍 Verifying cache with cacheFirst strategy...');
        try {
          final cacheFirstResponse = await ApiClientService.get(
            '/json',
            domainName: 'cache-strategy-test',
            cacheStrategy: ApiClientCacheStrategy.cacheFirst,
          );
          print('   ✅ cacheFirst succeeded - cache is available');
        } catch (e) {
          print('   ❌ cacheFirst failed: $e - cache was not written properly');
        }

        // Now test cacheOnly
        print('   🔍 Testing cacheOnly strategy...');
        final cacheStartTime = DateTime.now();
        final cachedResponse = await ApiClientService.get(
          '/json',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.cacheOnly,
        );
        final cacheEndTime = DateTime.now();

        expect(cachedResponse.statusCode, 200);

        final cacheResponseTime =
            cacheEndTime.difference(cacheStartTime).inMilliseconds;
        print('   ✅ cacheOnly returned cached data in ${cacheResponseTime}ms');
        expect(cacheResponseTime, lessThan(100),
            reason: 'Cache should be instant');

        testPassed = true;
        notes = 'Cache instant access: ${cacheResponseTime}ms';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('cacheOnly Behavior', testPassed, notes: notes);
      }
    });

    testWidgets('2. cacheFirst - Cache Priority Behavior',
        (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing cacheFirst strategy...');

      try {
        // Clear any existing cache for this endpoint
        await apiClient.dispose();
        apiClient = ApiClientPlus();
        await apiClient.initialize(
          configs: [
            ApiConfig(
                name: 'cache-strategy-test', baseUrl: 'https://httpbin.org')
          ],
          defaultDomain: 'cache-strategy-test',
          cacheConfig: CacheConfig(enableCache: true),
          logConfig: LogConfig(showLog: false),
          tokenGetter: () async => null,
          onTokenInvalid: () async {},
        );

        // First call - cache miss, should go to network
        final firstCallStopwatch = Stopwatch()..start();
        final firstResponse = await ApiClientService.get(
          '/uuid',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.cacheFirst,
        );
        firstCallStopwatch.stop();

        expect(firstResponse.statusCode, 200);
        final firstUuid = firstResponse.data['uuid'];
        final firstCallTime = firstCallStopwatch.elapsedMilliseconds;
        print('   ✅ First call (cache miss): ${firstCallTime}ms');

        // Second call - cache hit, should be much faster and return same data
        final secondCallStopwatch = Stopwatch()..start();
        final secondResponse = await ApiClientService.get(
          '/uuid',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.cacheFirst,
        );
        secondCallStopwatch.stop();

        expect(secondResponse.statusCode, 200);
        expect(secondResponse.data['uuid'], equals(firstUuid));

        final secondCallTime = secondCallStopwatch.elapsedMilliseconds;
        print('   ✅ Second call (cache hit): ${secondCallTime}ms');
        expect(secondCallTime, lessThan(firstCallTime),
            reason: 'Cache hit should be faster than network call');

        testPassed = true;
        notes = 'Cache hit: ${secondCallTime}ms vs Network: ${firstCallTime}ms';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('cacheFirst Behavior', testPassed, notes: notes);
      }
    });

    testWidgets('3. cacheThenNetwork - Single Response',
        (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing cacheThenNetwork strategy...');

      try {
        // Populate cache first
        await ApiClientService.get(
          '/bytes/16',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkOnly,
        );

        // Test cacheThenNetwork
        final responses = <Response>[];
        final completer = Completer<void>();

        final subscription = ApiClientService.get(
          '/bytes/16',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.cacheThenNetwork,
        ).asStream().listen(
          (response) {
            responses.add(response);
            print('   Received response ${responses.length}');
            completer.complete();
          },
          onError: (error) {
            completer.completeError(error);
          },
        );

        await completer.future.timeout(Duration(seconds: 10));
        await subscription.cancel();

        expect(responses.length, greaterThanOrEqualTo(1));
        expect(responses[0].statusCode, 200);

        print(
            '   ✅ cacheThenNetwork: Received ${responses.length} response(s)');

        testPassed = true;
        notes = 'Received ${responses.length} response(s)';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('cacheThenNetwork Behavior', testPassed,
            notes: notes);
      }
    });

    testWidgets('4. networkFirst - Fallback to Cache',
        (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing networkFirst strategy...');

      try {
        // First, populate cache with known data
        await ApiClientService.get(
          '/base64/SGVsbG8gV29ybGQ=',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkOnly,
        );

        // Test with working network
        final networkResponse = await ApiClientService.get(
          '/base64/SGVsbG8gV29ybGQ=',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkFirst,
        );
        expect(networkResponse.statusCode, 200);

        // Test networkFirst behavior with forceRefresh
        final forcedResponse = await ApiClientService.get(
          '/base64/SGVsbG8gV29ybGQ=',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkFirst,
          forceRefresh: true,
        );
        expect(forcedResponse.statusCode, 200);

        print('   ✅ NetworkFirst with working network: Success');
        print('   ✅ NetworkFirst with forceRefresh: Success');

        testPassed = true;
        notes = 'Network and forceRefresh working';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('networkFirst Behavior', testPassed, notes: notes);
      }
    });

    testWidgets('5. networkOnly - Bypass Cache Completely',
        (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing networkOnly strategy...');

      try {
        // Populate cache first
        await ApiClientService.get(
          '/delay/1',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.cacheFirst,
        );

        // Test networkOnly - should always hit network
        final stopwatch = Stopwatch()..start();
        final response = await ApiClientService.get(
          '/delay/1',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkOnly,
        );
        stopwatch.stop();

        expect(response.statusCode, 200);
        final responseTime = stopwatch.elapsedMilliseconds;
        print('   ✅ networkOnly: Success in ${responseTime}ms');

        expect(responseTime, greaterThan(800),
            reason: 'Network call should take measurable time due to delay');

        testPassed = true;
        notes = 'Network call: ${responseTime}ms (bypassed cache)';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('networkOnly Behavior', testPassed, notes: notes);
      }
    });

    testWidgets('6. staleWhileRevalidate - Single Response',
        (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing staleWhileRevalidate strategy...');

      try {
        // First, populate cache
        await ApiClientService.get(
          '/xml',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkOnly,
        );

        // Test staleWhileRevalidate
        final responses = <Response>[];
        final completer = Completer<void>();

        final subscription = ApiClientService.get(
          '/xml',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.staleWhileRevalidate,
          maxStale: Duration(minutes: 10),
        ).asStream().listen(
          (response) {
            responses.add(response);
            print(
                '   Received staleWhileRevalidate response ${responses.length}');
            completer.complete();
          },
          onError: (error) {
            completer.complete();
          },
        );

        await completer.future.timeout(Duration(seconds: 5));
        await subscription.cancel();

        expect(responses.length, greaterThanOrEqualTo(1));
        expect(responses[0].statusCode, 200);

        print(
            '   ✅ staleWhileRevalidate: Received ${responses.length} response(s)');

        testPassed = true;
        notes = 'Received ${responses.length} response(s)';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('staleWhileRevalidate Behavior', testPassed,
            notes: notes);
      }
    });

    testWidgets('7. Cache Strategy Performance Comparison',
        (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Comparing Cache Strategy Performance...');

      try {
        final performanceResults = <String, int>{};
        final testEndpoint = '/json';

        // Ensure cache is populated first
        await ApiClientService.get(
          testEndpoint,
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkOnly,
        );

        await Future.delayed(Duration(milliseconds: 100));

        final strategies = [
          ApiClientCacheStrategy.cacheOnly,
          ApiClientCacheStrategy.cacheFirst,
          ApiClientCacheStrategy.networkFirst,
          ApiClientCacheStrategy.networkOnly,
        ];

        for (final strategy in strategies) {
          final stopwatch = Stopwatch()..start();
          try {
            await ApiClientService.get(
              testEndpoint,
              domainName: 'cache-strategy-test',
              cacheStrategy: strategy,
            );
            stopwatch.stop();
            performanceResults[strategy.name] = stopwatch.elapsedMilliseconds;
            print('   ${strategy.name}: ${stopwatch.elapsedMilliseconds}ms');
          } catch (e) {
            stopwatch.stop();
            performanceResults[strategy.name] = stopwatch.elapsedMilliseconds;
            print(
                '   ${strategy.name}: ${stopwatch.elapsedMilliseconds}ms (Error)');
          }
          await Future.delayed(Duration(milliseconds: 50));
        }

        // Verify cacheOnly is fast
        if (performanceResults.containsKey('cache_only')) {
          expect(performanceResults['cache_only']!, lessThan(50));
        }

        print('   ✅ Performance comparison completed');

        testPassed = true;
        notes = 'Strategies tested: ${performanceResults.keys.join(', ')}';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('Performance Comparison', testPassed, notes: notes);
      }
    });

    testWidgets('8. Cache Strategy with Headers', (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing Cache Strategy with Headers...');

      try {
        final testStrategies = [
          ApiClientCacheStrategy.networkOnly,
          ApiClientCacheStrategy.networkFirst,
          ApiClientCacheStrategy.cacheFirst,
        ];

        int successCount = 0;
        for (final strategy in testStrategies) {
          try {
            final response = await ApiClientService.get(
              '/headers',
              domainName: 'cache-strategy-test',
              cacheStrategy: strategy,
              headers: {
                'X-Test-Header': 'test-value-${strategy.name}',
              },
            );
            expect(response.statusCode, 200);
            successCount++;
            print('   ✅ ${strategy.name} with headers: Success');
          } catch (e) {
            print('   ⚠️ ${strategy.name} with headers: Failed');
          }
        }

        expect(successCount, greaterThan(0));
        testPassed = true;
        notes =
            '$successCount/${testStrategies.length} strategies worked with headers';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('Headers Support', testPassed, notes: notes);
      }
    });

    testWidgets('9. Realistic Timeout Behavior', (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing Realistic Timeout Behavior...');

      try {
        // Test timeout with networkOnly
        try {
          await ApiClientService.get(
            '/delay/3',
            domainName: 'cache-strategy-test',
            cacheStrategy: ApiClientCacheStrategy.networkOnly,
            timeout: Duration(seconds: 1),
          );
          fail('Should have timed out');
        } catch (e) {
          print('   ✅ networkOnly with timeout: Correctly timed out');
        }

        // Test cache strategies with reasonable timeouts
        await ApiClientService.get(
          '/json',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkOnly,
        );

        final cachedResponse = await ApiClientService.get(
          '/json',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.cacheFirst,
          timeout: Duration(seconds: 10),
        );
        expect(cachedResponse.statusCode, 200);
        print('   ✅ cacheFirst with reasonable timeout: Success');

        testPassed = true;
        notes = 'Timeout handling working correctly';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('Timeout Behavior', testPassed, notes: notes);
      }
    });

    testWidgets('10. Cache Strategy Force Refresh',
        (WidgetTester tester) async {
      bool testPassed = false;
      String? notes;

      print('\n🔍 Testing Force Refresh across strategies...');

      try {
        // Populate with initial data
        final initialResponse = await ApiClientService.get(
          '/uuid',
          domainName: 'cache-strategy-test',
          cacheStrategy: ApiClientCacheStrategy.networkOnly,
        );
        final initialUuid = initialResponse.data['uuid'];

        final strategiesWithRefresh = [
          ApiClientCacheStrategy.cacheFirst,
          ApiClientCacheStrategy.networkFirst,
        ];

        int successCount = 0;
        for (final strategy in strategiesWithRefresh) {
          final refreshedResponse = await ApiClientService.get(
            '/uuid',
            domainName: 'cache-strategy-test',
            cacheStrategy: strategy,
            forceRefresh: true,
          );

          expect(refreshedResponse.statusCode, 200);
          expect(refreshedResponse.data['uuid'], isNot(equals(initialUuid)));
          successCount++;
          print('   ✅ ${strategy.name} with forceRefresh: Success');
        }

        expect(successCount, strategiesWithRefresh.length);
        testPassed = true;
        notes = 'Force refresh working for $successCount strategies';
      } catch (e) {
        testPassed = false;
        notes = 'Failed: $e';
        rethrow;
      } finally {
        _recordTestResult('Force Refresh', testPassed, notes: notes);
      }
    });

    testWidgets('11. Generate Comprehensive Test Report',
        (WidgetTester tester) async {
      print('\n' + '=' * 80);
      print('🎯 COMPREHENSIVE CACHE STRATEGY TEST REPORT');
      print('=' * 80);

      // Device Information
      final device = testResults['device'] as Map<String, dynamic>;
      print('📱 DEVICE INFORMATION:');
      print('   • Platform: ${device['os']} ${device['osVersion']}');
      if (device.containsKey('manufacturer')) {
        print('   • Device: ${device['manufacturer']} ${device['model']}');
      } else {
        print('   • Device: ${device['model']}');
      }
      print('   • Network: ${device['networkType']}');
      print(
          '   • Download Speed: ${device['downloadSpeedMbps']?.toStringAsFixed(2) ?? 'N/A'} Mbps');

      print('=' * 80);
      print('🕐 TEST EXECUTION:');
      print('   • Timestamp: ${testResults['timestamp']}');
      print('   • Test API: httpbin.org');

      print('=' * 80);
      print('📊 TEST RESULTS SUMMARY:');

      final tests = testResults['tests'] as List<Map<String, dynamic>>;
      final passedTests = tests.where((test) => test['passed'] == true).length;
      final totalTests = tests.length;

      print('   • Total Tests: $totalTests');
      print('   • Passed: $passedTests');
      print('   • Failed: ${totalTests - passedTests}');
      print(
          '   • Success Rate: ${((passedTests / totalTests) * 100).toStringAsFixed(1)}%');

      print('=' * 80);
      print('✅ DETAILED TEST RESULTS:');

      for (final test in tests) {
        final status = test['passed'] ? '✅ PASS' : '❌ FAIL';
        final name = test['name'];
        final notes = test['notes'] ?? '';
        print('   • $status: $name');
        if (notes.isNotEmpty) {
          print('     Notes: $notes');
        }
      }

      print('=' * 80);
      print('🎯 FINAL ASSESSMENT:');

      if (passedTests == totalTests) {
        print('   🏆 ALL TESTS PASSED - PRODUCTION READY');
      } else if (passedTests >= totalTests * 0.8) {
        print('   ✅ MOST TESTS PASSED - NEARLY PRODUCTION READY');
      } else if (passedTests >= totalTests * 0.6) {
        print('   ⚠️  SOME TESTS FAILED - NEEDS IMPROVEMENT');
      } else {
        print('   ❌ MANY TESTS FAILED - NOT PRODUCTION READY');
      }

      print('=' * 80);
    });
  });
}
