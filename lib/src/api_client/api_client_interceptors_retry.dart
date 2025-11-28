part of 'api_client_base.dart';

// Simple retry interceptor class
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final ApiConfig config;
  final bool showLog;

  RetryInterceptor(
      {required this.dio, required this.config, required this.showLog});

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final shouldRetry = _shouldRetry(err);

    if (shouldRetry && config.maxRetries > 0) {
      final retryCount = err.requestOptions.extra['retry_count'] as int? ?? 0;

      if (retryCount < config.maxRetries) {
        final delay = _calculateRetryDelay(retryCount);

        if (showLog) {
          FastLog.w(
              '🔄 Retrying request (${retryCount + 1}/${config.maxRetries}) in ${delay.inMilliseconds}ms',
              tag: "RETRY");
        }

        await Future.delayed(delay);

        final newOptions = err.requestOptions.copyWith(
          extra: {
            ...err.requestOptions.extra,
            'retry_count': retryCount + 1,
          },
        );

        try {
          final response = await dio.fetch(newOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          // If retry also fails, continue with original error
        }
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.unknown ||
        err.response?.statusCode == 502 ||
        err.response?.statusCode == 503;
  }

  Duration _calculateRetryDelay(int retryCount) {
    // Exponential backoff: 1s, 2s, 4s, etc.
    return Duration(seconds: 1 << retryCount);
  }
}
