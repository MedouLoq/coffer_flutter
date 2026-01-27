import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

/// Service API pour communiquer avec le backend Django
class ApiService {
  // ============================================================
  // CONFIG
  // ============================================================
  /// Base API (tout ce qui est dans vault_api.urls est sous /api/)
  static const String baseUrl = 'http://62.171.154.32:8000/api';

  /// Root serveur (http://127.0.0.1:8000)
  static final String _apiRoot = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  // ============================================================
  // AUTH (SimpleJWT)
  // IMPORTANT:
  // - Dans ton Django urls.py, tu as:
  //   POST /api/token/
  //   POST /api/token/refresh/
  // Donc ce n'est PAS /api/auth/token/
  // ============================================================
  static const String authRegister = '$baseUrl/auth/register/';

  /// ✅ CORRIGÉ : SimpleJWT -> /api/token/
  static final String authLogin = '$_apiRoot/api/token/';

  /// ✅ CORRIGÉ : SimpleJWT -> /api/token/refresh/
  static final String authRefresh = '$_apiRoot/api/token/refresh/';

  static const String authProfile = '$baseUrl/auth/profile/';

  // Vault key
  static const String vaultKey = '$baseUrl/vault/key/';
  static const String vaultKeyExistsUrl = '$baseUrl/vault/key/exists/';

  // Vault items + types
  static const String vaultItems = '$baseUrl/vault/items/';
  static const String vaultDocuments = '$baseUrl/vault/documents/';
  static const String vaultContacts = '$baseUrl/vault/contacts/';
  static const String vaultEvents = '$baseUrl/vault/events/';
  static const String vaultNotes = '$baseUrl/vault/notes/';

  // ============================================================
  // URL BUILDER
  // - URL complète: http://...
  // - "/api/xxx"    -> root + "/api/xxx"
  // - "/xxx"        -> baseUrl + "/xxx"
  // - "xxx"         -> baseUrl + "/xxx"
  // ============================================================
  static Uri _uri(String endpointOrUrl) {
    final e = endpointOrUrl.trim();

    if (e.startsWith('http://') || e.startsWith('https://')) {
      return Uri.parse(e);
    }

    // "/api/xxx" => root + "/api/xxx"
    if (e.startsWith('/api/')) {
      return Uri.parse('$_apiRoot$e');
    }

    // "/xxx" => baseUrl + "/xxx"
    if (e.startsWith('/')) {
      return Uri.parse('$baseUrl$e');
    }

    // "xxx" => baseUrl + "/xxx"
    return Uri.parse('$baseUrl/$e');
  }

  // ============================================================
  // HEADERS
  // ============================================================
  static Future<Map<String, String>> _getHeaders(
      {bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await SecureStorageService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================
  static dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body; // fallback texte (HTML, etc.)
    }
  }

  static dynamic _handleResponse(http.Response response) {
    final decoded = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? {'success': true};
    }

    String errorMessage = 'Erreur ${response.statusCode}';
    if (decoded is Map<String, dynamic>) {
      errorMessage = (decoded['detail'] ??
              decoded['error'] ??
              decoded['message'] ??
              errorMessage)
          .toString();
    } else if (decoded is String && decoded.isNotEmpty) {
      errorMessage = decoded;
    }

    throw ApiException(response.statusCode, errorMessage);
  }

  // ============================================================
  // LIST PARSING
  // ============================================================
  static List<Map<String, dynamic>> _asListOfMaps(dynamic data,
      {String? preferKey}) {
    if (data == null) return <Map<String, dynamic>>[];

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    if (data is Map<String, dynamic>) {
      final keyCandidates = <String>[
        if (preferKey != null) preferKey,
        'results',
        'items',
        'data',
      ];

      for (final k in keyCandidates) {
        final v = data[k];
        if (v is List) {
          return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }

      return <Map<String, dynamic>>[Map<String, dynamic>.from(data)];
    }

    throw ApiException(500, 'Format de réponse inattendu (liste attendue).');
  }

  // ============================================================
  // REQUEST HELPERS
  // ============================================================
  static Future<http.Response> _rawGet(String endpointOrUrl,
      {bool includeAuth = true}) async {
    return http.get(_uri(endpointOrUrl),
        headers: await _getHeaders(includeAuth: includeAuth));
  }

  static Future<http.Response> _rawPost(String endpointOrUrl,
      {bool includeAuth = true, Map<String, dynamic>? body}) async {
    return http.post(
      _uri(endpointOrUrl),
      headers: await _getHeaders(includeAuth: includeAuth),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
  }

  static Future<http.Response> _rawPatch(String endpointOrUrl,
      {bool includeAuth = true, Map<String, dynamic>? body}) async {
    return http.patch(
      _uri(endpointOrUrl),
      headers: await _getHeaders(includeAuth: includeAuth),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
  }

  static Future<http.Response> _rawDelete(String endpointOrUrl,
      {bool includeAuth = true}) async {
    return http.delete(_uri(endpointOrUrl),
        headers: await _getHeaders(includeAuth: includeAuth));
  }

  /// Helpers "haut niveau"
  static Future<dynamic> get(String endpointOrUrl,
      {bool includeAuth = true}) async {
    final res = await _rawGet(endpointOrUrl, includeAuth: includeAuth);
    return _handleResponse(res);
  }

  static Future<dynamic> post(String endpointOrUrl,
      {bool includeAuth = true, Map<String, dynamic>? body}) async {
    final res =
        await _rawPost(endpointOrUrl, includeAuth: includeAuth, body: body);
    return _handleResponse(res);
  }

  static Future<dynamic> patch(String endpointOrUrl,
      {bool includeAuth = true, Map<String, dynamic>? body}) async {
    final res =
        await _rawPatch(endpointOrUrl, includeAuth: includeAuth, body: body);
    return _handleResponse(res);
  }

  static Future<dynamic> delete(String endpointOrUrl,
      {bool includeAuth = true}) async {
    final res = await _rawDelete(endpointOrUrl, includeAuth: includeAuth);
    return _handleResponse(res);
  }

  // ============================================================
  // AUTH
  // ============================================================
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final data = await post(
      authRegister,
      includeAuth: false,
      body: {'username': username, 'email': email, 'password': password},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// ✅ CORRIGÉ : SimpleJWT attend par défaut {username, password}
  /// (sauf si tu as modifié Django pour accepter email)
  static Future<Map<String, dynamic>> login({
    required String username, // ✅ Change email → username
    required String password,
  }) async {
    final data = await post(
      authLogin,
      includeAuth: false,
      body: {'username': username, 'password': password}, // ✅ Corrigé
    );

    final map = Map<String, dynamic>.from(data as Map);

    if (map['access'] != null) {
      await SecureStorageService.saveTokens(
        accessToken: map['access'],
        refreshToken: map['refresh'],
      );
    }
    return map;
  }

  static Future<String?> refreshToken() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken == null) return null;

      final data = await post(
        authRefresh,
        includeAuth: false,
        body: {'refresh': refreshToken},
      );

      final map = Map<String, dynamic>.from(data as Map);
      final newAccessToken = map['access'];

      if (newAccessToken != null) {
        await SecureStorageService.saveTokens(
          accessToken: newAccessToken.toString(),
          refreshToken: refreshToken,
        );
      }

      return newAccessToken?.toString();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Erreur refresh token: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final data = await get(authProfile);
    return Map<String, dynamic>.from(data as Map);
  }

  // ============================================================
  // VAULT KEY
  // ============================================================
  static Future<bool> vaultKeyExists() async {
    try {
      final data = await get(vaultKeyExistsUrl);
      if (data is Map<String, dynamic>) return data['exists'] == true;
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Erreur vaultKeyExists: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getVaultKey() async {
    try {
      final data = await get(vaultKey);
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createVaultKey({
    required String kdfSaltB64,
    required int kdfIterations,
    required String wrappedDekB64,
    required String dekNonceB64,
    required String dekTagB64,
  }) async {
    final data = await post(
      vaultKey,
      body: {
        'kdf_salt_b64': kdfSaltB64,
        'kdf_iters': kdfIterations,
        'wrapped_dek_b64': wrappedDekB64,
        'dek_nonce_b64': dekNonceB64,
        'dek_tag_b64': dekTagB64,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  // ============================================================
  // VAULT ITEMS (CRUD)
  // ============================================================
  static Future<List<Map<String, dynamic>>> getItems({String? itemType}) async {
    var url = vaultItems;
    if (itemType != null && itemType.isNotEmpty) {
      url = '$url?type=$itemType';
    }

    final data = await get(url);
    return _asListOfMaps(data);
  }

  static Future<Map<String, dynamic>> createItem({
    required String itemType,
    required String ciphertextB64,
    required String nonceB64,
    required String tagB64,
    String? metaCiphertextB64,
    String? metaNonceB64,
    String? metaTagB64,
    int size = 0,
    int version = 1,
    String? deviceId,
  }) async {
    final data = await post(
      vaultItems,
      body: {
        'item_type': itemType,
        'ciphertext_b64': ciphertextB64,
        'nonce_b64': nonceB64,
        'tag_b64': tagB64,
        'meta_ciphertext_b64': metaCiphertextB64 ?? '',
        'meta_nonce_b64': metaNonceB64 ?? '',
        'meta_tag_b64': metaTagB64 ?? '',
        'size': size,
        'version': version,
        'device_id': deviceId,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> updateItem({
    required String itemId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await patch('$vaultItems$itemId/', body: updates);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> deleteItem(String itemId) async {
    await delete('$vaultItems$itemId/');
  }

  // ============================================================
  // ENDPOINTS PAR TYPE
  // ============================================================
  static Future<List<Map<String, dynamic>>> getDocuments() async {
    final data = await get(vaultDocuments);
    return _asListOfMaps(data);
  }

  static Future<Map<String, dynamic>> createDocument(
      Map<String, dynamic> data) async {
    final res = await post(vaultDocuments, body: data);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<List<Map<String, dynamic>>> getContacts() async {
    final data = await get(vaultContacts);
    return _asListOfMaps(data);
  }

  static Future<Map<String, dynamic>> createContact(
      Map<String, dynamic> data) async {
    final res = await post(vaultContacts, body: data);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<List<Map<String, dynamic>>> getEvents(
      {String? from, String? to}) async {
    var url = vaultEvents;
    final params = <String>[];
    if (from != null && from.isNotEmpty) params.add('from=$from');
    if (to != null && to.isNotEmpty) params.add('to=$to');
    if (params.isNotEmpty) url = '$url?${params.join('&')}';

    final data = await get(url);
    return _asListOfMaps(data);
  }

  static Future<Map<String, dynamic>> createEvent(
      Map<String, dynamic> data) async {
    final res = await post(vaultEvents, body: data);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<List<Map<String, dynamic>>> getNotes() async {
    final data = await get(vaultNotes);
    return _asListOfMaps(data);
  }

  static Future<Map<String, dynamic>> createNote(
      Map<String, dynamic> data) async {
    final res = await post(vaultNotes, body: data);
    return Map<String, dynamic>.from(res as Map);
  }

  // ============================================================
  // SYNC
  // ============================================================
  static Future<Map<String, dynamic>> pushItems({
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await post('${vaultItems}sync/push/', body: {'items': items});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> pullItems({String? since}) async {
    var url = '${vaultItems}sync/pull/';
    if (since != null && since.isNotEmpty) {
      url = '$url?since=$since';
    }

    final data = await get(url);
    return _asListOfMaps(data, preferKey: 'items');
  }

  // ============================================================
  // UTILS
  // ============================================================
  static Future<bool> ping() async {
    try {
      final response = await http.get(
        _uri('/api/health/'),
        headers: const {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Ping serveur échoué: $e');
      return false;
    }
  }

  static Future<bool> isAuthenticated() async {
    try {
      await getProfile();
      return true;
    } catch (_) {
      final newToken = await refreshToken();
      return newToken != null;
    }
  }
}

/// Exception API personnalisée
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
