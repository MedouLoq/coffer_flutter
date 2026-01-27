import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Service de chiffrement Zero-Knowledge
/// - Dérivation PBKDF2 (HMAC-SHA256)
/// - Chiffrement AES-256-GCM
/// - Stockage items local: base64(nonce || ciphertext || tag)
///
/// + WRAP/UNWRAP de la DEK:
///   - DEK (32 bytes) est chiffrée avec KEK (clé dérivée du mot de passe)
class CryptoService {
  // Paramètres de sécurité
  static const int kdfIterations = 300;
  static const int saltLength = 32; // 256 bits
  static const int nonceLength = 12; // 96 bits (GCM)
  static const int tagLength = 16; // 128 bits (GCM)
  static const int dekLength = 32; // 256 bits (DEK)

  // ==========================================
  // RANDOM
  // ==========================================
  static Uint8List randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => r.nextInt(256)));
  }

  static Uint8List generateSalt() => randomBytes(saltLength);

  // ==========================================
  // KDF (PBKDF2)
  // ==========================================
  static Uint8List deriveKey({
    required String password,
    required Uint8List salt,
    int iterations = kdfIterations,
    int length = 32,
  }) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, iterations, length));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static bool isValidKey(Uint8List key) => key.length == 32;

  // ==========================================
  // PACK/UNPACK (nonce||ciphertext||tag)
  // ==========================================
  static String packCombinedB64({
    required Uint8List nonce,
    required Uint8List ciphertext,
    required Uint8List tag,
  }) {
    final combined = Uint8List.fromList([...nonce, ...ciphertext, ...tag]);
    return base64Encode(combined);
  }

  static ({Uint8List nonce, Uint8List ciphertext, Uint8List tag})
      unpackCombinedB64(
    String combinedB64,
  ) {
    final combined = base64Decode(combinedB64);
    if (combined.length < nonceLength + tagLength + 1) {
      throw FormatException('Données chiffrées invalides (trop courtes)');
    }

    final nonce = combined.sublist(0, nonceLength);
    final tag = combined.sublist(combined.length - tagLength);
    final ciphertext =
        combined.sublist(nonceLength, combined.length - tagLength);

    return (nonce: nonce, ciphertext: ciphertext, tag: tag);
  }

  // ==========================================
  // AES-GCM core (returns ciphertext + tag separately)
  // ==========================================
  static ({Uint8List nonce, Uint8List ciphertext, Uint8List tag}) encryptRaw(
    Uint8List plain,
    Uint8List key, {
    Uint8List? aad,
  }) {
    if (!isValidKey(key)) {
      throw ArgumentError('Clé invalide (doit faire 32 bytes)');
    }

    final nonce = randomBytes(nonceLength);
    final cipher = GCMBlockCipher(AESEngine());

    final params = AEADParameters(
      KeyParameter(key),
      tagLength * 8,
      nonce,
      aad ?? Uint8List(0),
    );

    cipher.init(true, params);

    // PointyCastle GCMBlockCipher renvoie (ciphertext || tag) en fin de flux
    final out = cipher.process(plain);
    if (out.length < tagLength + 1) {
      throw Exception('Chiffrement GCM invalide');
    }

    final tag = out.sublist(out.length - tagLength);
    final ciphertext = out.sublist(0, out.length - tagLength);

    return (nonce: nonce, ciphertext: ciphertext, tag: tag);
  }

  static Uint8List decryptRaw(
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List tag,
    Uint8List key, {
    Uint8List? aad,
  }) {
    if (!isValidKey(key)) {
      throw ArgumentError('Clé invalide (doit faire 32 bytes)');
    }

    final cipher = GCMBlockCipher(AESEngine());

    final params = AEADParameters(
      KeyParameter(key),
      tagLength * 8,
      nonce,
      aad ?? Uint8List(0),
    );

    cipher.init(false, params);

    // Pour déchiffrer, il faut repasser (ciphertext || tag)
    final input = Uint8List.fromList([...ciphertext, ...tag]);

    return cipher.process(input);
  }

  // ==========================================
  // TEXT helpers
  // ==========================================
  static String encryptText(String plaintext, Uint8List key) {
    final plain = Uint8List.fromList(utf8.encode(plaintext));
    final parts = encryptRaw(plain, key);
    return packCombinedB64(
        nonce: parts.nonce, ciphertext: parts.ciphertext, tag: parts.tag);
  }

  static String decryptText(String combinedB64, Uint8List key) {
    final p = unpackCombinedB64(combinedB64);
    final plain = decryptRaw(p.nonce, p.ciphertext, p.tag, key);
    return utf8.decode(plain);
  }

  // ==========================================
  // BYTES helpers
  // ==========================================
  static String encryptBytes(Uint8List data, Uint8List key) {
    final parts = encryptRaw(data, key);
    return packCombinedB64(
        nonce: parts.nonce, ciphertext: parts.ciphertext, tag: parts.tag);
  }

  static Uint8List decryptBytes(String combinedB64, Uint8List key) {
    final p = unpackCombinedB64(combinedB64);
    return decryptRaw(p.nonce, p.ciphertext, p.tag, key);
  }

  // ==========================================
  // WRAP / UNWRAP DEK with KEK (master password derived key)
  // ==========================================
  static ({String wrappedDekB64, String dekNonceB64, String dekTagB64})
      wrapDek({
    required Uint8List dek,
    required Uint8List kek,
  }) {
    if (dek.length != dekLength) {
      throw ArgumentError('DEK invalide (doit faire $dekLength bytes)');
    }
    final parts = encryptRaw(dek, kek);
    return (
      wrappedDekB64: base64Encode(parts.ciphertext),
      dekNonceB64: base64Encode(parts.nonce),
      dekTagB64: base64Encode(parts.tag),
    );
  }

  static Uint8List unwrapDek({
    required String wrappedDekB64,
    required String dekNonceB64,
    required String dekTagB64,
    required Uint8List kek,
  }) {
    final ciphertext = base64Decode(wrappedDekB64);
    final nonce = base64Decode(dekNonceB64);
    final tag = base64Decode(dekTagB64);

    final dek = decryptRaw(nonce, ciphertext, tag, kek);
    if (dek.length != dekLength) {
      throw Exception('DEK déchiffrée invalide (taille incorrecte)');
    }
    return dek;
  }

  // ==========================================
  // UTILS
  // ==========================================
  static String keyToBase64(Uint8List key) => base64Encode(key);
  static Uint8List base64ToKey(String s) => base64Decode(s);

  static String hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  static bool testEncryption(Uint8List key) {
    try {
      const s = 'Test de chiffrement 🔐';
      final enc = encryptText(s, key);
      final dec = decryptText(enc, key);
      return dec == s;
    } catch (_) {
      return false;
    }
  }
}
