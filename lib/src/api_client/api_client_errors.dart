part of 'api_client_base.dart';

// Error handling extension
extension ApiClientErrors on ApiClientPlus {
  ApiClientError _wrapDioException(DioException e, String domain, String path) {
    String errorType = 'UNKNOWN_ERROR';
    String message = e.message ?? 'Unknown error occurred';
    int? statusCode;
    dynamic responseData;

    switch (e.type) {
      case DioExceptionType.connectionError:
        errorType = 'NETWORK_ERROR';
        message =
            'Network connection failed: ${e.message ?? "Unable to connect to server"}';
        break;

      case DioExceptionType.connectionTimeout:
        errorType = 'CONNECTION_TIMEOUT';
        message =
            'Connection timeout: Unable to establish connection with server';
        break;

      case DioExceptionType.receiveTimeout:
        errorType = 'RECEIVE_TIMEOUT';
        message = 'Receive timeout: Server took too long to respond';
        break;

      case DioExceptionType.sendTimeout:
        errorType = 'SEND_TIMEOUT';
        message = 'Send timeout: Request took too long to send';
        break;

      case DioExceptionType.badResponse:
        statusCode = e.response?.statusCode;
        responseData = e.response?.data;
        errorType = _getErrorTypeFromStatusCode(statusCode);
        message = _getErrorMessageFromResponse(e.response, statusCode);
        break;

      case DioExceptionType.cancel:
        errorType = 'CANCELLED';
        message = 'Request was cancelled';
        break;

      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          errorType = 'NETWORK_UNAVAILABLE';
          message = 'No internet connection available';
        } else if (e.error is HandshakeException) {
          errorType = 'SSL_ERROR';
          message = 'SSL handshake failed: ${e.error}';
        } else {
          errorType = 'UNKNOWN_ERROR';
          message = 'Unknown error: ${e.error ?? "No error details"}';
        }
        break;

      case DioExceptionType.badCertificate:
        errorType = 'SSL_CERTIFICATE_ERROR';
        message = 'SSL certificate verification failed';
        break;

      // ignore: unreachable_switch_default
      default:
        errorType = 'CLIENT_ERROR';
        message = 'Client error: ${e.message ?? "Unknown client error"}';
    }

    // Ensure we have valid strings
    final safeDomain = domain.isNotEmpty ? domain : 'unknown';
    final safePath = path.isNotEmpty ? path : '/';

    return ApiClientError(
      message: message,
      type: errorType,
      domain: safeDomain,
      path: safePath,
      statusCode: statusCode,
      originalException: e,
      responseData: responseData,
    );
  }

  String _getErrorTypeFromStatusCode(int? statusCode) {
    if (statusCode == null) return 'UNKNOWN_ERROR';

    switch (statusCode) {
      case 400:
        return 'BAD_REQUEST';
      case 401:
        return 'UNAUTHORIZED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 405:
        return 'METHOD_NOT_ALLOWED';
      case 408:
        return 'REQUEST_TIMEOUT';
      case 409:
        return 'CONFLICT';
      case 422:
        return 'VALIDATION_ERROR';
      case 429:
        return 'RATE_LIMITED';
      case 500:
        return 'INTERNAL_SERVER_ERROR';
      case 502:
        return 'BAD_GATEWAY';
      case 503:
        return 'SERVICE_UNAVAILABLE';
      case 504:
        return 'GATEWAY_TIMEOUT';
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return 'CLIENT_ERROR';
        } else if (statusCode >= 500) {
          return 'SERVER_ERROR';
        } else {
          return 'HTTP_${statusCode}';
        }
    }
  }

  String _getErrorMessageFromResponse(Response? response, int? statusCode) {
    if (response == null) {
      return 'Server error: $statusCode';
    }

    // Try to extract message from common response formats
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data['message'] ??
          data['error'] ??
          data['description'] ??
          response.statusMessage ??
          'Server error: $statusCode';
    }

    if (data is String) {
      return data.isNotEmpty
          ? data
          : response.statusMessage ?? 'Server error: $statusCode';
    }

    return response.statusMessage ?? 'Server error: $statusCode';
  }

  /// Helper method to check if error is due to network issues
  bool isNetworkError(ApiClientError error) {
    return error.type == 'NETWORK_ERROR' ||
        error.type == 'NETWORK_UNAVAILABLE' ||
        error.type == 'CONNECTION_TIMEOUT';
  }

  /// Helper method to check if error is due to authentication
  bool isAuthError(ApiClientError error) {
    return error.type == 'UNAUTHORIZED' ||
        error.type == 'FORBIDDEN' ||
        error.statusCode == 401 ||
        error.statusCode == 403;
  }

  /// Helper method to check if error is retryable
  bool isRetryableError(ApiClientError error) {
    return isNetworkError(error) ||
        error.type == 'RECEIVE_TIMEOUT' ||
        error.type == 'SEND_TIMEOUT' ||
        error.statusCode == 408 || // Request Timeout
        error.statusCode == 429 || // Too Many Requests
        error.statusCode == 502 || // Bad Gateway
        error.statusCode == 503 || // Service Unavailable
        error.statusCode == 504; // Gateway Timeout
  }
}
