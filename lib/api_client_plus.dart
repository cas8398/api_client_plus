library api_client_plus;

/// API Client Plus - High-performance HTTP client with intelligent caching
///
/// ## Quick Start
/// ```dart
/// import 'package:api_client_plus/api_client_plus.dart';
///
/// await ApiClientService.initialize(...);
/// final response = await ApiClientService.get('/users');
/// ```

// 🚀 CORE FUNCTIONALITY
export 'src/api_client/api_client_service.dart' show ApiClientService;
export 'src/api_client/api_client_base.dart' show ApiClientPlus;

// ⚡ CACHE STRATEGIES
export 'src/api_client/api_client_cache_strategy.dart'
    show ApiClientCacheStrategy, ApiClientCacheStrategyExtension;

// 🔧 CONFIGURATION
export 'src/models/api_config.dart' show ApiConfig;
export 'src/models/cache_config.dart' show CacheConfig;
export 'src/models/log_config.dart' show LogConfig, LogStyle;

// 📦 RESPONSE & ERROR HANDLING
export 'src/models/api_error.dart' show ApiClientError;
export 'src/models/request_options.dart' show ApiRequestOptions;
