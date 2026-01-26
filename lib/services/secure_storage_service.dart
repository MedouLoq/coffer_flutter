import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé (Chrome = fallback Web/IndexedDB selon plugin)
/// Ce service est "compatibilité maximale" avec ton code existant:
/// - JWT tokens (ApiService)
/// - pin_service.dart read/write/deleteKey
/// - splash_view.dart isLoggedIn / hasVaultKey
/// - vault_controller.dart (kdf + wrapped dek)
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // -------------------------
  // KEYS AUTH (JWT)
  // -------------------------
  static const String _kAccessToken = 'access_token';
  static const String _kRefreshToken = 'refresh_token';

  // -------------------------
  // USER
  // -------------------------
  static const String _kUserId = 'user_id';
  static const String _kUserEmail = 'user_email';

  // -------------------------
  // VAULT (KDF + Wrapped DEK)
  // -------------------------
  static const String _kKdfSalt = 'kdf_salt_b64';
  static const String _kKdfIters = 'kdf_iters';

  static const String _kWrappedDek = 'wrapped_dek_b64';
  static const String _kDekNonce = 'dek_nonce_b64';
  static const String _kDekTag = 'dek_tag_b64';

  // ancien flag utilisé parfois
  static const String _kVaultCreated = 'vault_created';

  // -------------------------
  // GENERIC helpers (PinService)
  // -------------------------
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  static Future<void> deleteKey(String key) async {
    await _storage.delete(key: key);
  }

  // -------------------------
  // TOKENS (ApiService)
  // -------------------------
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _kRefreshToken);

  // -------------------------
  // USER INFO
  // -------------------------
  static Future<void> saveUserInfo({
    required String userId,
    required String email,
  }) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kUserEmail, value: email);
  }

  static Future<String?> getUserId() => _storage.read(key: _kUserId);
  static Future<String?> getUserEmail() => _storage.read(key: _kUserEmail);

  // -------------------------
  // KDF PARAMS
  // -------------------------
  static Future<void> saveKdfParams({
    required String saltBase64,
    required int iterations,
  }) async {
    await _storage.write(key: _kKdfSalt, value: saltBase64);
    await _storage.write(key: _kKdfIters, value: iterations.toString());
  }

  static Future<String?> getKdfSalt() => _storage.read(key: _kKdfSalt);

  static Future<int> getKdfIterations() async {
    final s = await _storage.read(key: _kKdfIters);
    return int.tryParse(s ?? '') ?? 300000;
  }

  // -------------------------
  // VAULT KEY (wrapped DEK)
  // -------------------------
  static Future<void> saveWrappedDek({
    required String wrappedDekB64,
    required String dekNonceB64,
    required String dekTagB64,
  }) async {
    await _storage.write(key: _kWrappedDek, value: wrappedDekB64);
    await _storage.write(key: _kDekNonce, value: dekNonceB64);
    await _storage.write(key: _kDekTag, value: dekTagB64);
  }

  static Future<String?> getWrappedDek() => _storage.read(key: _kWrappedDek);
  static Future<String?> getDekNonce() => _storage.read(key: _kDekNonce);
  static Future<String?> getDekTag() => _storage.read(key: _kDekTag);

  /// Pour Splash : est-ce qu'on a une VaultKey locale ?
  static Future<bool> hasVaultKey() async {
    final w = await getWrappedDek();
    final n = await getDekNonce();
    final t = await getDekTag();
    final s = await getKdfSalt();
    return (w != null && w.isNotEmpty) &&
        (n != null && n.isNotEmpty) &&
        (t != null && t.isNotEmpty) &&
        (s != null && s.isNotEmpty);
  }

  /// Pour Splash : est-ce que l'utilisateur est connecté (token existant) ?
  static Future<bool> isLoggedIn() async {
    final a = await getAccessToken();
    final r = await getRefreshToken();
    return (a != null && a.isNotEmpty) || (r != null && r.isNotEmpty);
  }

  // -------------------------
  // VAULT CREATED FLAG
  // -------------------------
  static Future<void> markVaultCreated() async {
    await _storage.write(key: _kVaultCreated, value: '1');
  }

  static Future<bool> isVaultCreated() async {
    return (await _storage.read(key: _kVaultCreated)) == '1';
  }

  // -------------------------
  // CLEAR
  // -------------------------
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Efface seulement auth (tokens) => utilisé par VaultController.logout()
  static Future<void> clearAuthOnly() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}
