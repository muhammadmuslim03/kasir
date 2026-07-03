import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../model/user_role.dart';
import 'app_exception.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required String baseUrl,
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  }) : _storage = secureStorage ?? const FlutterSecureStorage(),
       _baseUrl = baseUrl,
       _httpClient = httpClient ?? http.Client();

  static const _tokenKey = 'kasir_auth_token';
  static const _roleKey = 'kasir_auth_role';
  static const _requestTimeout = Duration(seconds: 3);

  final FlutterSecureStorage _storage;
  final String _baseUrl;
  final http.Client _httpClient;

  String? _token;
  UserRole _role = UserRole.cashier;
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  String? get token => _token;
  UserRole get role => _role;
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();

    try {
      final token = await _storage.read(key: _tokenKey);
      final roleValue = await _storage.read(key: _roleKey);
      final storedRole = userRoleFromApi(
        roleValue ?? UserRole.cashier.apiValue,
      );
      if (token != null && token.isNotEmpty && storedRole == UserRole.cashier) {
        _token = token;
        _role = storedRole;
      } else {
        await loginAs(UserRole.cashier, notify: false);
      }
      _error = null;
    } catch (error) {
      _error = 'Tidak dapat login ke backend: $error';
    } finally {
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loginAs(
    UserRole role, {
    String? ownerPin,
    bool notify = true,
  }) async {
    _loading = true;
    _error = null;
    if (notify) {
      notifyListeners();
    }

    try {
      final session = await _demoLogin(role, ownerPin: ownerPin);
      _token = session.token;
      _role = session.role;
      await _storage.write(key: _tokenKey, value: session.token);
      await _storage.write(key: _roleKey, value: session.role.apiValue);
    } catch (error) {
      _error = 'Login gagal: $error';
      rethrow;
    } finally {
      _loading = false;
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<void> loginOwnerWithPin(String pin, {bool notify = true}) {
    return loginAs(UserRole.owner, ownerPin: pin, notify: notify);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    _token = null;
    _role = UserRole.cashier;
    notifyListeners();
  }

  Future<({String token, UserRole role})> _demoLogin(
    UserRole role, {
    String? ownerPin,
  }) async {
    final normalizedBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final response = await _httpClient
        .post(
          Uri.parse('$normalizedBase/api/auth/demo-login'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'role': role.apiValue,
            if (role == UserRole.owner) 'pin': ownerPin ?? '',
          }),
        )
        .timeout(_requestTimeout);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map<String, dynamic> && decoded['error'] is String
          ? decoded['error'] as String
          : 'Login demo gagal (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    }

    final data = decoded as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      role: userRoleFromApi(data['role'] as String),
    );
  }
}
