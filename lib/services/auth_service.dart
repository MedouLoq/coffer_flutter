import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'auth_storage.dart';

class AuthService {
  String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    return 'http://10.0.2.2:8000/api';
  }

  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/token/');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Login échoué (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access'] as String?;

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Token JWT manquant');
    }

    await AuthStorage.saveToken(accessToken);
  }

  Future<void> signUpWithUsername({
    required String username,
    required String password,
    String? email,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register/');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': (email ?? '').trim(),
        'password': password,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Inscription échouée (${response.statusCode})');
    }
  }

  Future<void> signOut() async {
    await AuthStorage.clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await AuthStorage.getToken();
    return token != null && token.isNotEmpty;
  }
}
