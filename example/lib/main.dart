import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:api_client_plus/api_client_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Minimal setup
  await ApiClientPlus().initialize(
    configs: [
      ApiConfig(
        name: 'dev',
        baseUrl: 'https://api.dev.example.com',
        requiresAuth: true,
      ),
      ApiConfig(
        name: 'prod',
        baseUrl: 'https://api.example.com',
        requiresAuth: true,
      ),
      ApiConfig(
        name: 'auth',
        baseUrl: 'https://api.example.com',
        requiresAuth: false,
      ),
    ],
    defaultDomain: kReleaseMode ? 'prod' : 'dev',
    cacheConfig: CacheConfig(
      enableCache: true,
      defaultTtl: Duration(minutes: 10),
    ),
    logConfig: LogConfig(
      showLog: kReleaseMode,
      showCacheLog: false,
      messageLimit: 300,
      prettyJson: false,
      isColored: true,
      showCaller: false,
      logStyle: LogStyle.minimal,
      logLevel: "DEBUG",
    ),
    tokenGetter: () async {
      // final prefs = await SharedPreferences.getInstance();
      // return prefs.getString('access_token');
      return 'my_access_token';
    },
    onTokenInvalid: () async {
      // Redirect logic here
    },
    onRequest: (options) async {
      options.headers['User-Agent'] = 'MyApp/1.0.0';
    },
    onResponse: (response) async {
      debugPrint('✅ ${response.statusCode} ${response.requestOptions.path}');
    },
    onError: (error) async {
      debugPrint('❌ API Error: ${error.message}');
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
