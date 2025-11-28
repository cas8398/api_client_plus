import 'package:dio/dio.dart';

class ApiClientError implements Exception {
  final String message;
  final String type;
  final String domain;
  final String path;
  final int? statusCode;
  final DioException? originalException;
  final dynamic responseData;

  ApiClientError({
    required this.message,
    required this.type,
    required this.domain,
    required this.path,
    this.statusCode,
    this.originalException,
    this.responseData,
  }) {
    // Ensure all required fields are properly initialized
    assert(message.isNotEmpty, 'Error message cannot be empty');
    assert(type.isNotEmpty, 'Error type cannot be empty');
    assert(domain.isNotEmpty, 'Domain cannot be empty');
    assert(path.isNotEmpty, 'Path cannot be empty');
  }

  @override
  String toString() {
    return '[$type] $message (Domain: $domain, Path: $path${statusCode != null ? ', Status: $statusCode' : ''})';
  }
}
