import 'package:flutter/material.dart';
import 'package:api_client_plus/api_client_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Minimal setup
  await ApiClientPlus().initialize(
    configs: [
      ApiConfig(
        name: 'example',
        baseUrl: 'https://example.com',
        connectTimeout: Duration(seconds: 30),
        receiveTimeout: Duration(seconds: 30),
        sendTimeout: Duration(seconds: 30),
        verboseLogging: false,
      ),
      ApiConfig(
        name: 'dummyjson',
        baseUrl: 'https://dummyjson.com',
        verboseLogging: true,
      ),
    ],
    defaultDomain: 'dummyjson',
    cacheConfig: CacheConfig(
      enableCache: true,
      defaultTtl: Duration(minutes: 1),
    ),
    logConfig: LogConfig(
      showLog: true,
      showCacheLog: false,
      messageLimit: 300,
      prettyJson: false,
      isColored: true,
      showCaller: false,
      logStyle: LogStyle.minimal,
      logLevel: "DEBUG",
    ),
    tokenGetter: () async => null,
    onTokenInvalid: () async {},
    onCachedResponse: (response) async {
      debugPrint('📦 ApiClientPlus response from cache ');
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Simple GET Demo')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              try {
                final response = await ApiClientService.get(
                  '/posts/1',
                  useCache: true,
                  cacheStrategy: ApiClientCacheStrategy.cacheThenNetwork,
                );
                debugPrint('Post title: ${response.data['title']}');
              } catch (e, stackTrace) {
                // Handle errors gracefully
                debugPrint('Failed to fetch post: $e');
                debugPrint(stackTrace.toString());
              }
            },
            child: const Text('Make GET Request'),
          ),
        ),
      ),
    );
  }
}
