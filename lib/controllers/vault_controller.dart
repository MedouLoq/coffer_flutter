import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../services/crypto_service.dart';
import '../services/db_service.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import '../models/vault_item_model.dart';

class VaultController extends GetxController {
  final isUnlocked = false.obs;
  final isLoading = false.obs;

  // ✅ DEK en mémoire uniquement (sert à chiffrer/déchiffrer items)
  Uint8List? _dek;
  Uint8List? get encryptionKey => _dek;

  String? currentUserId;
  String? currentUserEmail;

  late String deviceId;

  final files = <VaultItem>[].obs;
  final contacts = <VaultItem>[].obs;
  final events = <VaultItem>[].obs;
  final notes = <VaultItem>[].obs;

  // ✅ Catégories de fichiers (FINI correctement)
  final Map<String, List<String>> fileCategories = {
    'Documents': ['.pdf', '.doc', '.docx', '.txt', '.md'],
    'Images': ['.jpg', '.jpeg', '.png', '.gif', '.svg', '.webp'],
    'Videos': ['.mp4', '.avi', '.mov', '.mkv', '.webm'],
    'Audio': ['.mp3', '.wav', '.flac', '.m4a', '.ogg'],
    'Archives': ['.zip', '.rar', '.7z', '.tar', '.gz'],
    'Code': ['.dart', '.js', '.py', '.java', '.cpp', '.html', '.css'],
  };

  @override
  void onInit() {
    super.onInit();
    deviceId = const Uuid().v4();
    _checkExistingVault();
  }

  Future<void> _checkExistingVault() async {
    try {
      currentUserId = await SecureStorageService.getUserId();
      currentUserEmail = await SecureStorageService.getUserEmail();

      final created = await SecureStorageService.isVaultCreated();
      if (created && currentUserId != null) {
        print('✅ Vault détecté pour $currentUserEmail');
      }
    } catch (e) {
      print('❌ Erreur vérification vault: $e');
    }
  }

  // ==========================================================
  // CREATE VAULT (Zero-knowledge)
  // ==========================================================
  Future<bool> createVault({
    required String userId,
    required String email,
    required String masterPassword,
  }) async {
    try {
      isLoading.value = true;

      // 1) Générer salt + dériver KEK
      final salt = CryptoService.generateSalt();
      final kek = CryptoService.deriveKey(
        password: masterPassword,
        salt: salt,
        iterations: CryptoService.kdfIterations,
      );

      if (!CryptoService.testEncryption(kek)) {
        throw Exception('Échec test crypto (KEK)');
      }

      // 2) Générer DEK aléatoire (celle qui chiffre toutes les données)
      final dek = CryptoService.randomBytes(CryptoService.dekLength);

      // 3) Wrap DEK avec KEK (AES-GCM)
      final wrapped = CryptoService.wrapDek(dek: dek, kek: kek);

      // 4) Envoyer au serveur (VaultKey en DB)
      await ApiService.createVaultKey(
        kdfSaltB64: CryptoService.keyToBase64(salt),
        kdfIterations: CryptoService.kdfIterations,
        wrappedDekB64: wrapped.wrappedDekB64,
        dekNonceB64: wrapped.dekNonceB64,
        dekTagB64: wrapped.dekTagB64,
      );

      // 5) Cache local (optionnel mais pratique)
      await SecureStorageService.saveUserInfo(userId: userId, email: email);
      await SecureStorageService.saveKdfParams(
        saltBase64: CryptoService.keyToBase64(salt),
        iterations: CryptoService.kdfIterations,
      );
      await SecureStorageService.saveWrappedDek(
        wrappedDekB64: wrapped.wrappedDekB64,
        dekNonceB64: wrapped.dekNonceB64,
        dekTagB64: wrapped.dekTagB64,
      );
      await SecureStorageService.markVaultCreated();

      // 6) Déverrouillé
      _dek = dek;
      currentUserId = userId;
      currentUserEmail = email;
      isUnlocked.value = true;

      print('✅ Vault créé (DEK wrappée stockée serveur) pour $email');
      return true;
    } catch (e) {
      print('❌ Erreur création vault: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================================
  // UNLOCK VAULT (Zero-knowledge)
  // ==========================================================
  Future<bool> unlockVault(String masterPassword) async {
    try {
      isLoading.value = true;

      // 1) Récup user
      currentUserId = await SecureStorageService.getUserId();
      currentUserEmail = await SecureStorageService.getUserEmail();
      if (currentUserId == null) {
        throw Exception('Utilisateur introuvable (userId null)');
      }

      // 2) Récup VaultKey (serveur d’abord)
      Map<String, dynamic>? vk;
      try {
        vk = await ApiService.getVaultKey();
      } catch (_) {
        vk = null;
      }

      // fallback: cache local si serveur indispo
      vk ??= await _loadVaultKeyFromCache();

      if (vk == null) {
        throw Exception('VaultKey introuvable (serveur + cache)');
      }

      final kdfSaltB64 = (vk['kdf_salt_b64'] ?? '') as String;
      final kdfIters = (vk['kdf_iters'] ?? CryptoService.kdfIterations) as int;
      final wrappedDekB64 = (vk['wrapped_dek_b64'] ?? '') as String;
      final dekNonceB64 = (vk['dek_nonce_b64'] ?? '') as String;
      final dekTagB64 = (vk['dek_tag_b64'] ?? '') as String;

      if (kdfSaltB64.isEmpty ||
          wrappedDekB64.isEmpty ||
          dekNonceB64.isEmpty ||
          dekTagB64.isEmpty) {
        throw Exception('VaultKey invalide (champs manquants)');
      }

      final salt = CryptoService.base64ToKey(kdfSaltB64);

      // 3) dériver KEK depuis mot de passe
      final kek = CryptoService.deriveKey(
        password: masterPassword,
        salt: salt,
        iterations: kdfIters,
      );

      // 4) UNWRAP DEK (si mauvais mdp => exception GCM)
      final dek = CryptoService.unwrapDek(
        wrappedDekB64: wrappedDekB64,
        dekNonceB64: dekNonceB64,
        dekTagB64: dekTagB64,
        kek: kek,
      );

      // 5) OK
      _dek = dek;
      isUnlocked.value = true;

      // Cache les params pour offline
      await SecureStorageService.saveKdfParams(
        saltBase64: kdfSaltB64,
        iterations: kdfIters,
      );
      await SecureStorageService.saveWrappedDek(
        wrappedDekB64: wrappedDekB64,
        dekNonceB64: dekNonceB64,
        dekTagB64: dekTagB64,
      );

      await loadAllData();

      print('✅ Vault déverrouillé pour $currentUserEmail');
      return true;
    } catch (e) {
      print('❌ Erreur déverrouillage: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>?> _loadVaultKeyFromCache() async {
    final salt = await SecureStorageService.getKdfSalt();
    final iters = await SecureStorageService.getKdfIterations();

    final wrappedDek = await SecureStorageService.getWrappedDek();
    final nonce = await SecureStorageService.getDekNonce();
    final tag = await SecureStorageService.getDekTag();

    if (salt == null || wrappedDek == null || nonce == null || tag == null) {
      return null;
    }

    return {
      'kdf_salt_b64': salt,
      'kdf_iters': iters,
      'wrapped_dek_b64': wrappedDek,
      'dek_nonce_b64': nonce,
      'dek_tag_b64': tag,
    };
  }

  // ==========================================================
  // LOAD DATA (local DB)
  // ==========================================================
  Future<void> loadAllData() async {
    if (!isUnlocked.value || currentUserId == null) return;

    await Future.wait([
      loadFiles(),
      loadContacts(),
      loadEvents(),
      loadNotes(),
    ]);
  }

  Future<void> loadFiles() async {
    if (currentUserId == null) return;
    try {
      final rows = await DBService.query(
        DBService.tableFiles,
        where: 'user_id = ? AND deleted = ?',
        whereArgs: [currentUserId, 0],
        orderBy: 'updated_at DESC',
      );

      files.value =
          rows.map((row) => VaultItem.fromDb(row, VaultItemType.file)).toList();
      print('📂 ${files.length} fichiers chargés');
    } catch (e) {
      print('❌ Erreur chargement fichiers: $e');
    }
  }

  Future<void> loadContacts() async {
    if (currentUserId == null) return;
    try {
      final rows = await DBService.query(
        DBService.tableContacts,
        where: 'user_id = ? AND deleted = ?',
        whereArgs: [currentUserId, 0],
        orderBy: 'updated_at DESC',
      );
      contacts.value = rows
          .map((row) => VaultItem.fromDb(row, VaultItemType.contact))
          .toList();
      print('👥 ${contacts.length} contacts chargés');
    } catch (e) {
      print('❌ Erreur chargement contacts: $e');
    }
  }

  Future<void> loadEvents() async {
    if (currentUserId == null) return;
    try {
      final rows = await DBService.query(
        DBService.tableEvents,
        where: 'user_id = ? AND deleted = ?',
        whereArgs: [currentUserId, 0],
        orderBy: 'event_date DESC',
      );
      events.value = rows
          .map((row) => VaultItem.fromDb(row, VaultItemType.event))
          .toList();
      print('📅 ${events.length} événements chargés');
    } catch (e) {
      print('❌ Erreur chargement événements: $e');
    }
  }

  Future<void> loadNotes() async {
    if (currentUserId == null) return;
    try {
      final rows = await DBService.query(
        DBService.tableNotes,
        where: 'user_id = ? AND deleted = ?',
        whereArgs: [currentUserId, 0],
        orderBy: 'updated_at DESC',
      );
      notes.value =
          rows.map((row) => VaultItem.fromDb(row, VaultItemType.note)).toList();
      print('📝 ${notes.length} notes chargées');
    } catch (e) {
      print('❌ Erreur chargement notes: $e');
    }
  }

  // ==========================================================
  // ADD ITEMS
  // ==========================================================
  Future<bool> addFile({required String filename, required Uint8List data}) async {
    if (_dek == null || currentUserId == null) return false;

    try {
      final encryptedData = CryptoService.encryptBytes(data, _dek!);
      final category = getFileCategory(filename);

      final item = VaultItem(
        userId: currentUserId!,
        type: VaultItemType.file,
        encryptedData: encryptedData,
        filename: filename,
        category: category,
        size: data.length,
        deviceId: deviceId,
      );

      await DBService.insert(DBService.tableFiles, item.toDb());
      await loadFiles();

      print('✅ Fichier ajouté: $filename ($category)');
      return true;
    } catch (e) {
      print('❌ Erreur ajout fichier: $e');
      return false;
    }
  }

  Future<bool> addContact(Map<String, dynamic> contactData) async {
    if (_dek == null || currentUserId == null) return false;

    try {
      final jsonData = contactData.toString();
      final encryptedData = CryptoService.encryptText(jsonData, _dek!);

      final item = VaultItem(
        userId: currentUserId!,
        type: VaultItemType.contact,
        encryptedData: encryptedData,
        title: contactData['name'] as String?,
      );

      await DBService.insert(DBService.tableContacts, item.toDb());
      await loadContacts();
      return true;
    } catch (e) {
      print('❌ Erreur ajout contact: $e');
      return false;
    }
  }

  Future<bool> addEvent({
    required DateTime eventDate,
    required Map<String, dynamic> eventData,
  }) async {
    if (_dek == null || currentUserId == null) return false;

    try {
      final jsonData = eventData.toString();
      final encryptedData = CryptoService.encryptText(jsonData, _dek!);

      final item = VaultItem(
        userId: currentUserId!,
        type: VaultItemType.event,
        encryptedData: encryptedData,
        eventDate: eventDate.toIso8601String(),
        title: eventData['title'] as String?,
      );

      await DBService.insert(DBService.tableEvents, item.toDb());
      await loadEvents();
      return true;
    } catch (e) {
      print('❌ Erreur ajout événement: $e');
      return false;
    }
  }

  Future<bool> addNote({required String title, required String content}) async {
    if (_dek == null || currentUserId == null) return false;

    try {
      final encryptedData = CryptoService.encryptText(content, _dek!);

      final item = VaultItem(
        userId: currentUserId!,
        type: VaultItemType.note,
        encryptedData: encryptedData,
        title: title,
      );

      await DBService.insert(DBService.tableNotes, item.toDb());
      await loadNotes();
      return true;
    } catch (e) {
      print('❌ Erreur ajout note: $e');
      return false;
    }
  }

  // ==========================================================
  // DECRYPT
  // ==========================================================
  String decryptItem(VaultItem item) {
    if (_dek == null) throw Exception('Vault non déverrouillé');
    return CryptoService.decryptText(item.encryptedData, _dek!);
  }

  Uint8List decryptBinary(VaultItem item) {
    if (_dek == null) throw Exception('Vault non déverrouillé');
    return CryptoService.decryptBytes(item.encryptedData, _dek!);
  }

  // ==========================================================
  // DELETE
  // ==========================================================
  Future<bool> deleteItem(VaultItem item) async {
    try {
      await DBService.markAsDeleted(item.type.tableName, item.id!);
      await loadAllData();
      return true;
    } catch (e) {
      print('❌ Erreur suppression: $e');
      return false;
    }
  }

  // ==========================================================
  // HELPERS utilisés par DocumentsTab  ✅✅
  // ==========================================================
  String decryptItemById(dynamic id) {
    final key = encryptionKey;
    if (key == null) throw Exception('Vault non déverrouillé');
    if (id == null) throw Exception('ID null');

    final int? intId = (id is int) ? id : int.tryParse(id.toString());
    if (intId == null) throw Exception('ID invalide');

    VaultItem? item;
    for (final f in files) {
      if (f.id == intId) {
        item = f;
        break;
      }
    }
    if (item == null) throw Exception('Document introuvable');

    try {
      return CryptoService.decryptText(item.encryptedData, key);
    } catch (_) {
      return '[Contenu binaire : impossible à afficher en texte]';
    }
  }

  Future<bool> deleteFileById(dynamic id) async {
    if (id == null) return false;

    final int? intId = (id is int) ? id : int.tryParse(id.toString());
    if (intId == null) return false;

    try {
      await DBService.markAsDeleted(DBService.tableFiles, intId);
      await loadAllData();
      return true;
    } catch (e) {
      print('❌ Erreur deleteFileById: $e');
      return false;
    }
  }

  // ==========================================================
  // SYNC
  // ==========================================================
  Future<void> syncWithServer() async {
    if (currentUserId == null) return;

    try {
      isLoading.value = true;
      final result = await SyncService.sync(userId: currentUserId!);

      if (result.success) {
        await loadAllData();
        Get.snackbar(
          '✅ Synchronisation réussie',
          'Push: ${result.itemsPushed}, Pull: ${result.itemsPulled}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          '❌ Erreur de sync',
          result.message,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Erreur sync: $e');
      Get.snackbar('Erreur', 'Sync échouée: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void enableAutoSync() {
    if (currentUserId != null) {
      SyncService.startAutoSync(
        userId: currentUserId!,
        interval: const Duration(minutes: 5),
      );
    }
  }

  void disableAutoSync() {
    SyncService.stopAutoSync();
  }

  // ==========================================================
  // LOCK/LOGOUT/RESET
  // ==========================================================
  Future<void> lockVault() async {
    _dek = null;
    isUnlocked.value = false;

    files.clear();
    contacts.clear();
    events.clear();
    notes.clear();

    disableAutoSync();
    print('🔒 Vault verrouillé');
  }

  Future<void> logout() async {
    await lockVault();
    await SecureStorageService.clearAuthOnly();
    currentUserId = null;
    currentUserEmail = null;
  }

  Future<void> resetVault() async {
    await SecureStorageService.clearAll();
    await DBService.delete(DBService.tableFiles);
    await DBService.delete(DBService.tableContacts);
    await DBService.delete(DBService.tableEvents);
    await DBService.delete(DBService.tableNotes);
    await lockVault();
  }

  // ==========================================================
  // HELPERS
  // ==========================================================
  String getFileCategory(String filename) {
    final lower = filename.toLowerCase();
    for (final entry in fileCategories.entries) {
      if (entry.value.any((ext) => lower.endsWith(ext))) return entry.key;
    }
    return 'Autres';
  }

  @override
  void onClose() {
    disableAutoSync();
    SyncService.dispose();
    super.onClose();
  }
}
