import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'secure_storage_service.dart';

/// Service de gestion du code PIN de vérification
/// Utilisé pour sécuriser l'accès en lecture aux données sensibles
class PinService {
  static const String _keyPinHash = 'pin_hash';
  static const String _keyPinEnabled = 'pin_enabled';
  static const String _keyPinAttempts = 'pin_attempts';
  static const String _keyPinLockUntil = 'pin_lock_until';
  
  static const int maxAttempts = 3;
  static const Duration lockDuration = Duration(minutes: 5);

  // ==========================================
  // CONFIGURATION DU PIN
  // ==========================================

  /// Active le PIN avec un code à 4-6 chiffres
  static Future<bool> setupPin(String pin) async {
    if (!_isValidPin(pin)) {
      throw ArgumentError('Le PIN doit contenir 4 à 6 chiffres');
    }

    try {
      final hash = _hashPin(pin);
      await SecureStorageService.write(_keyPinHash, hash);
      await SecureStorageService.write(_keyPinEnabled, 'true');
      await _resetAttempts();
      
      print('🔢 PIN configuré avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur setup PIN: $e');
      return false;
    }
  }

  /// Vérifie si le PIN est activé
  static Future<bool> isPinEnabled() async {
    final enabled = await SecureStorageService.read(_keyPinEnabled);
    return enabled == 'true';
  }

  /// Désactive le PIN (nécessite vérification d'abord)
  static Future<void> disablePin() async {
    await SecureStorageService.deleteKey(_keyPinHash);
    await SecureStorageService.deleteKey(_keyPinEnabled);
    await _resetAttempts();
    print('🔓 PIN désactivé');
  }

  /// Change le PIN (nécessite l'ancien PIN)
  static Future<bool> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    if (!await verifyPin(oldPin)) {
      return false;
    }

    return await setupPin(newPin);
  }

  // ==========================================
  // VÉRIFICATION DU PIN
  // ==========================================

  /// Vérifie si le PIN est correct
  static Future<bool> verifyPin(String pin) async {
    // Vérifier si verrouillé
    if (await _isLocked()) {
      final remaining = await _getRemainingLockTime();
      throw PinLockedException('Verrouillé pendant encore $remaining');
    }

    final storedHash = await SecureStorageService.read(_keyPinHash);
    if (storedHash == null) {
      throw Exception('PIN non configuré');
    }

    final inputHash = _hashPin(pin);
    final isValid = storedHash == inputHash;

    if (isValid) {
      await _resetAttempts();
      print('✅ PIN correct');
      return true;
    } else {
      await _incrementAttempts();
      final attempts = await _getAttempts();
      print('❌ PIN incorrect (tentative $attempts/$maxAttempts)');

      if (attempts >= maxAttempts) {
        await _lockPin();
        throw PinLockedException('Trop de tentatives. Verrouillé pendant 5 minutes.');
      }

      return false;
    }
  }

  // ==========================================
  // GESTION DES TENTATIVES
  // ==========================================

  static Future<int> _getAttempts() async {
    final value = await SecureStorageService.read(_keyPinAttempts);
    return value != null ? int.tryParse(value) ?? 0 : 0;
  }

  static Future<void> _incrementAttempts() async {
    final current = await _getAttempts();
    await SecureStorageService.write(
      _keyPinAttempts,
      (current + 1).toString(),
    );
  }

  static Future<void> _resetAttempts() async {
    await SecureStorageService.deleteKey(_keyPinAttempts);
    await SecureStorageService.deleteKey(_keyPinLockUntil);
  }

  // ==========================================
  // VERROUILLAGE TEMPORAIRE
  // ==========================================

  static Future<void> _lockPin() async {
    final lockUntil = DateTime.now().add(lockDuration);
    await SecureStorageService.write(
      _keyPinLockUntil,
      lockUntil.toIso8601String(),
    );
    print('🔒 PIN verrouillé jusqu\'à $lockUntil');
  }

  static Future<bool> _isLocked() async {
    final lockUntilStr = await SecureStorageService.read(_keyPinLockUntil);
    if (lockUntilStr == null) return false;

    final lockUntil = DateTime.parse(lockUntilStr);
    return DateTime.now().isBefore(lockUntil);
  }

  static Future<String> _getRemainingLockTime() async {
    final lockUntilStr = await SecureStorageService.read(_keyPinLockUntil);
    if (lockUntilStr == null) return '0 secondes';

    final lockUntil = DateTime.parse(lockUntilStr);
    final remaining = lockUntil.difference(DateTime.now());

    if (remaining.isNegative) {
      await _resetAttempts();
      return '0 secondes';
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return '${minutes}min ${seconds}s';
  }

  /// Récupère le temps restant de verrouillage (pour affichage)
  static Future<Duration?> getRemainingLockDuration() async {
    if (!await _isLocked()) return null;

    final lockUntilStr = await SecureStorageService.read(_keyPinLockUntil);
    if (lockUntilStr == null) return null;

    final lockUntil = DateTime.parse(lockUntilStr);
    final remaining = lockUntil.difference(DateTime.now());

    return remaining.isNegative ? null : remaining;
  }

  // ==========================================
  // UTILITAIRES
  // ==========================================

  static bool _isValidPin(String pin) {
    if (pin.length < 4 || pin.length > 6) return false;
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  static String _hashPin(String pin) {
    // Utiliser un salt fixe par utilisateur (ou global)
    // Dans une vraie app, utiliser un salt unique par utilisateur stocké séparément
    final salt = 'vault_pin_salt_2026';
    final combined = '$salt:$pin';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Obtient le nombre de tentatives restantes
  static Future<int> getRemainingAttempts() async {
    final current = await _getAttempts();
    return maxAttempts - current;
  }

  /// Statistiques (debug)
  static Future<Map<String, dynamic>> getStats() async {
    return {
      'enabled': await isPinEnabled(),
      'locked': await _isLocked(),
      'attempts': await _getAttempts(),
      'remaining_attempts': await getRemainingAttempts(),
      'lock_duration': await getRemainingLockDuration(),
    };
  }
}

/// Exception levée quand le PIN est verrouillé
class PinLockedException implements Exception {
  final String message;
  PinLockedException(this.message);

  @override
  String toString() => 'PinLockedException: $message';
}