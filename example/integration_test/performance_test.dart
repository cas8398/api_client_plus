import 'package:api_client_plus_example/speed_test.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:api_client_plus/api_client_plus.dart';
import 'grade_performace.dart';
import 'dart:io' show Platform;
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('🚀 Dynamic Performance Test Suite', () {
    // Test results storage
    final testResults = <String, dynamic>{};
    PerformanceMetrics? finalMetrics;

    setUpAll(() async {
      final deviceInfoPlugin = DeviceInfoPlugin();
      Map<String, dynamic> deviceData = {};

      final connectivityResult = await Connectivity().checkConnectivity();
      String connectionType;
      switch (connectivityResult) {
        // ignore: constant_pattern_never_matches_value_type
        case ConnectivityResult.mobile:
          connectionType = 'Mobile';
          break;
        // ignore: constant_pattern_never_matches_value_type
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

      // Save to test results for report
      testResults['device'] = deviceData;
      testResults['timestamp'] = DateTime.now().toString();
      testResults['networkType'] = connectionType;
      testResults['downloadSpeedMbps'] = speedTest;
    });

    testWidgets('1. Cold Start Performance Test (Log Enable: false)',
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      final apiClient = ApiClientPlus();
      await apiClient.initialize(
        configs: [
          ApiConfig(
            name: 'performance-test',
            baseUrl: 'https://jsonplaceholder.typicode.com',
            connectTimeout: Duration(seconds: 30),
            receiveTimeout: Duration(seconds: 30),
            sendTimeout: Duration(seconds: 30),
          ),
        ],
        defaultDomain: 'performance-test',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(
          enableCache: true,
          defaultTtl: Duration(minutes: 15),
        ),
        logConfig: LogConfig(showLog: false),
      );

      stopwatch.stop();
      final coldStartTime = stopwatch.elapsedMilliseconds;

      testResults['coldStartMs'] = coldStartTime;
      print('📦 Cold Start: ${coldStartTime}ms');

      await apiClient.dispose();
    });

    testWidgets('2. Cache Read/Write Performance Test',
        (WidgetTester tester) async {
      final apiClient = ApiClientPlus();
      await apiClient.initialize(
        configs: [
          ApiConfig(
            name: 'cache-test',
            baseUrl: 'https://jsonplaceholder.typicode.com',
          ),
        ],
        defaultDomain: 'cache-test',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(enableCache: true),
        logConfig: LogConfig(showLog: false),
      );

      const iterations = 5;
      final readTimes = <int>[];
      final writeTimes = <int>[];

      for (int i = 0; i < iterations; i++) {
        // Write test (network + cache)
        final writeStopwatch = Stopwatch()..start();
        try {
          await ApiClientService.get('/posts/${i + 1}',
              domainName: 'cache-test');
        } catch (e) {
          // Continue on error
        }
        writeStopwatch.stop();
        writeTimes.add(writeStopwatch.elapsedMilliseconds);

        await Future.delayed(Duration(milliseconds: 200));

        // Read test (cache hit)
        final readStopwatch = Stopwatch()..start();
        try {
          await ApiClientService.get('/posts/${i + 1}',
              domainName: 'cache-test');
        } catch (e) {
          // Continue on error
        }
        readStopwatch.stop();
        readTimes.add(readStopwatch.elapsedMilliseconds);

        await Future.delayed(Duration(milliseconds: 300));
      }

      final avgWriteTime = writeTimes.reduce((a, b) => a + b) ~/ iterations;
      final avgReadTime = readTimes.reduce((a, b) => a + b) ~/ iterations;
      final speedup = ((avgWriteTime - avgReadTime) / avgWriteTime * 100);

      testResults['avgCacheWriteMs'] = avgWriteTime;
      testResults['avgCacheReadMs'] = avgReadTime;
      testResults['cacheSpeedupPercent'] = speedup;

      print('💾 Cache Performance:');
      print('   Write: ${avgWriteTime}ms, Read: ${avgReadTime}ms');
      print('   Speedup: ${speedup.toStringAsFixed(1)}%');

      await apiClient.dispose();
    });

    testWidgets('3. Concurrency & Throughput Test',
        (WidgetTester tester) async {
      final apiClient = ApiClientPlus();
      await apiClient.initialize(
        configs: [
          ApiConfig(
            name: 'concurrency-test',
            baseUrl: 'https://jsonplaceholder.typicode.com',
          ),
        ],
        defaultDomain: 'concurrency-test',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(enableCache: true),
        logConfig: LogConfig(showLog: false),
      );

      const concurrentRequests = 10;
      final completionTimes = <int>[];

      final stopwatch = Stopwatch()..start();
      final futures = List.generate(concurrentRequests, (i) async {
        final requestStopwatch = Stopwatch()..start();
        try {
          await ApiClientService.get('/posts/${(i % 10) + 1}',
              domainName: 'concurrency-test');
        } catch (e) {
          // Continue on error
        }
        requestStopwatch.stop();
        completionTimes.add(requestStopwatch.elapsedMilliseconds);
      });

      await Future.wait(futures, eagerError: false);
      stopwatch.stop();

      final totalTime = stopwatch.elapsedMilliseconds;
      final avgRequestTime =
          completionTimes.reduce((a, b) => a + b) ~/ completionTimes.length;
      final throughput = (concurrentRequests / totalTime) * 1000;

      testResults['avgRequestMs'] = avgRequestTime;
      testResults['throughput'] = throughput;

      print('🧠 Concurrency:');
      print('   Avg Request: ${avgRequestTime}ms');
      print('   Throughput: ${throughput.toStringAsFixed(2)} req/sec');

      await apiClient.dispose();
    });

    testWidgets('4. Domain Switching Performance Test',
        (WidgetTester tester) async {
      final apiClient = ApiClientPlus();
      await apiClient.initialize(
        configs: [
          ApiConfig(
              name: 'domain-a',
              baseUrl: 'https://jsonplaceholder.typicode.com'),
          ApiConfig(
              name: 'domain-b',
              baseUrl: 'https://jsonplaceholder.typicode.com'),
          ApiConfig(
              name: 'domain-c',
              baseUrl: 'https://jsonplaceholder.typicode.com'),
        ],
        defaultDomain: 'domain-a',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(enableCache: true),
        logConfig: LogConfig(showLog: false),
      );

      const switches = 6;
      final switchTimes = <int>[];

      for (int i = 0; i < switches; i++) {
        final domain = ['domain-a', 'domain-b', 'domain-c'][i % 3];
        final stopwatch = Stopwatch()..start();

        try {
          final endpoint = domain == 'domain-a'
              ? '/users/1'
              : domain == 'domain-b'
                  ? '/posts/1'
                  : '/comments/1';
          await ApiClientService.get(endpoint, domainName: domain);
        } catch (e) {
          // Continue on error
        }

        stopwatch.stop();
        switchTimes.add(stopwatch.elapsedMilliseconds);
        await Future.delayed(Duration(milliseconds: 200));
      }

      final avgSwitchTime = switchTimes.reduce((a, b) => a + b) ~/ switches;
      testResults['avgDomainSwitchMs'] = avgSwitchTime;

      print('🔄 Domain Switching: ${avgSwitchTime}ms');

      await apiClient.dispose();
    });

    testWidgets('5. Error Recovery Performance Test',
        (WidgetTester tester) async {
      final apiClient = ApiClientPlus();
      await apiClient.initialize(
        configs: [
          ApiConfig(
            name: 'error-test',
            baseUrl: 'https://jsonplaceholder.typicode.com',
          ),
        ],
        defaultDomain: 'error-test',
        tokenGetter: () async => null,
        onTokenInvalid: () async {},
        cacheConfig: CacheConfig(enableCache: true),
        logConfig: LogConfig(showLog: false),
      );

      const errorTests = 5;
      final recoveryTimes = <int>[];

      for (int i = 0; i < errorTests; i++) {
        final stopwatch = Stopwatch()..start();

        try {
          await ApiClientService.get('/invalid-endpoint-$i',
                  domainName: 'error-test')
              .timeout(Duration(milliseconds: 500));
        } catch (e) {
          // Expected error
        }

        stopwatch.stop();
        recoveryTimes.add(stopwatch.elapsedMilliseconds);

        // Test recovery with valid request
        try {
          await ApiClientService.get('/posts/1', domainName: 'error-test');
        } catch (e) {
          // Continue on error
        }

        await Future.delayed(Duration(milliseconds: 100));
      }

      final avgRecoveryTime =
          recoveryTimes.reduce((a, b) => a + b) ~/ errorTests;
      testResults['avgErrorRecoveryMs'] = avgRecoveryTime;

      print('🛡️ Error Recovery: ${avgRecoveryTime}ms');

      await apiClient.dispose();
    });

    testWidgets('6. Generate Final Performance Report',
        (WidgetTester tester) async {
      // Create metrics from test results
      finalMetrics = PerformanceMetrics(
        coldStartMs: testResults['coldStartMs'],
        avgCacheReadMs: testResults['avgCacheReadMs'],
        avgCacheWriteMs: testResults['avgCacheWriteMs'],
        avgRequestMs: testResults['avgRequestMs'],
        throughput: testResults['throughput'],
        avgErrorRecoveryMs: testResults['avgErrorRecoveryMs'],
        avgDomainSwitchMs: testResults['avgDomainSwitchMs'],
        cacheSpeedupPercent: testResults['cacheSpeedupPercent'],
      );

      // Calculate grade
      final grade = PerformanceGrader.gradePerformance(finalMetrics!);
      final gradeDescription = PerformanceGrader.getGradeDescription(grade);
      final performanceTips =
          PerformanceGrader.getPerformanceTips(finalMetrics!);

      // Generate comprehensive report
      print('\n' + '=' * 70);
      print('🎯 DYNAMIC PERFORMANCE REPORT');
      print('=' * 70);
      print('📊 Performance Metrics:');
      print('   • Cold Start: ${finalMetrics!.coldStartMs}ms');
      print('   • Cache Read: ${finalMetrics!.avgCacheReadMs}ms');
      print('   • Cache Write: ${finalMetrics!.avgCacheWriteMs}ms');
      print('   • Request Time: ${finalMetrics!.avgRequestMs}ms');
      print(
          '   • Throughput: ${finalMetrics!.throughput.toStringAsFixed(2)} req/sec');
      print('   • Error Recovery: ${finalMetrics!.avgErrorRecoveryMs}ms');
      print('   • Domain Switch: ${finalMetrics!.avgDomainSwitchMs}ms');
      print(
          '   • Cache Speedup: ${finalMetrics!.cacheSpeedupPercent.toStringAsFixed(1)}%');
      print('');
      print('🏆 Performance Grade: $grade - $gradeDescription');
      print('');

      if (performanceTips.isNotEmpty) {
        print('💡 Optimization Tips:');
        performanceTips.forEach((key, tip) {
          print('   • $tip');
        });
      } else {
        print('✅ Excellent performance - no optimization needed!');
      }

      print('=' * 70);
      print('📈 Raw Test Results:');
      print(testResults);
      print('=' * 70);

      // Store final results
      testResults['finalGrade'] = grade.toString();
      testResults['finalMetrics'] = finalMetrics!.toJson();
      testResults['performanceTips'] = performanceTips;

      // Verify all metrics were collected
      expect(finalMetrics!.coldStartMs, greaterThan(0));
      expect(finalMetrics!.avgCacheReadMs, greaterThan(0));
      expect(finalMetrics!.avgCacheWriteMs, greaterThan(0));
      expect(finalMetrics!.avgRequestMs, greaterThan(0));
      expect(finalMetrics!.throughput, greaterThan(0));
    });
  });
}
