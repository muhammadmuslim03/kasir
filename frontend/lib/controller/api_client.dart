import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_exception.dart';
import 'auth_controller.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.authController,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final AuthController authController;
  final http.Client _httpClient;
  static const _requestTimeout = Duration(seconds: 8);

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final response = await _httpClient
        .get(_uri(path, query), headers: _headers())
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final response = await _httpClient
        .post(_uri(path), headers: _headers(), body: jsonEncode(body))
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    final response = await _httpClient
        .put(_uri(path), headers: _headers(), body: jsonEncode(body))
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<dynamic> deleteJson(String path) async {
    final response = await _httpClient
        .delete(_uri(path), headers: _headers())
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    final token = authController.token;
    if (token == null || token.isEmpty) {
      throw const ApiException('Token login belum tersedia');
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body is Map<String, dynamic> && body['error'] is String
        ? body['error'] as String
        : 'Request gagal (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
