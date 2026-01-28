import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/crypto_service.dart';
import '../models/vault_item_model.dart';
import 'dart:convert';

/// Service de synchronisation offline-first
/// - Push: envoie les modifications locales vers le serveur
/// - Pull: récupère les modifications du serveur
/// - Gestion des conflits par version
class SyncService {
  static DateTime? _lastSyncTime;
  static bool _isSyncing = false;
  static final _syncController = StreamController<SyncStatus>.broadcast();

  // Stream pour écouter les changements de statut
  static Stream<SyncStatus> get syncStream => _syncController.stream;

  // ==========================================
  // SYNCHRONISATION COMPLÈTE
  // ==========================================

  /// Lance une synchronisation complète (push + pull)
  // ==========================================
  // SYNCHRONISATION COMPLÈTE
  // ==========================================

  /// Lance une synchronisation complète (push + pull)
  static Future<SyncResult> sync({
    required String userId,
    bool forceFull = false,
  }) async {
    if (_isSyncing) {
      print('⏳ Synchronisation déjà en cours');
      return SyncResult(
        success: false,
        message: 'Sync déjà en cours',
      );
    }

    _isSyncing = true;

    // SAFEGUARD 1: Check before adding
    if (!_syncController.isClosed) {
      _syncController.add(SyncStatus.syncing);
    }

    try {
      // Vérifier la connexion
      if (!await _hasConnection()) {
        throw Exception('Pas de connexion internet');
      }

      // Vérifier l'authentification
      if (!await ApiService.isAuthenticated()) {
        throw Exception('Non authentifié');
      }

      int pushed = 0;
      int pulled = 0;
      int conflicts = 0;

      // 1. PUSH: envoyer les modifications locales
      final pushResult = await _pushLocalChanges(userId);
      pushed = pushResult.itemsCount;
      conflicts += pushResult.conflicts;

      // 2. PULL: récupérer les modifications serveur
      final since = forceFull ? null : _lastSyncTime?.toIso8601String();
      final pullResult = await _pullServerChanges(userId, since: since);
      pulled = pullResult.itemsCount;
      conflicts += pullResult.conflicts;

      // Marquer la dernière sync
      _lastSyncTime = DateTime.now();

      final result = SyncResult(
        success: true,
        message: 'Sync réussie',
        itemsPushed: pushed,
        itemsPulled: pulled,
        conflicts: conflicts,
        timestamp: _lastSyncTime!,
      );

      // SAFEGUARD 2: Check before adding success
      if (!_syncController.isClosed) {
        _syncController.add(SyncStatus.success);
      }
      print('✅ Sync terminée: push=$pushed, pull=$pulled, conflits=$conflicts');

      return result;
    } catch (e) {
      print('❌ Erreur sync: $e');

      // SAFEGUARD 3: Check before adding error
      if (!_syncController.isClosed) {
        _syncController.add(SyncStatus.error);
      }

      return SyncResult(
        success: false,
        message: 'Erreur: $e',
      );
    } finally {
      _isSyncing = false;
    }
  }
  // ==========================================
  // PUSH (Local → Serveur)
  // ==========================================

  static Future<_SyncOpResult> _pushLocalChanges(String userId) async {
    int pushed = 0;
    int conflicts = 0;

    // Récupérer tous les items à synchroniser
    final tables = [
      DBService.tableFiles,
      DBService.tableContacts,
      DBService.tableEvents,
      DBService.tableNotes,
    ];

    for (final table in tables) {
      final pendingItems = await DBService.getPendingSync(table, userId);

      for (final itemMap in pendingItems) {
        try {
          final type = _getItemTypeFromTable(table);
          final item = VaultItem.fromDb(itemMap, type);

          if (item.deleted) {
            // Supprimer côté serveur
            if (item.serverId != null) {
              await ApiService.deleteItem(item.serverId!);
              // Supprimer localement après confirmation
              await DBService.delete(
                table,
                where: 'id = ?',
                whereArgs: [item.id],
              );
            }
          } else if (item.serverId == null) {
            // Créer côté serveur (nouvel item)
            final response = await _createItemOnServer(item);

            // Mettre à jour avec le server_id
            await DBService.update(
              table,
              {
                'server_id': response['id'],
                'sync_status': 0,
                'version': response['version'] ?? 1,
              },
              where: 'id = ?',
              whereArgs: [item.id],
            );
          } else {
            // Mettre à jour côté serveur (item existant)
            try {
              await _updateItemOnServer(item);

              await DBService.update(
                table,
                {'sync_status': 0},
                where: 'id = ?',
                whereArgs: [item.id],
              );
            } on ApiException catch (e) {
              if (e.statusCode == 409) {
                // Conflit de version
                conflicts++;
                await _handleConflict(item, table);
              } else {
                rethrow;
              }
            }
          }

          pushed++;
        } catch (e) {
          print('❌ Erreur push item ${itemMap['id']}: $e');
        }
      }
    }

    return _SyncOpResult(itemsCount: pushed, conflicts: conflicts);
  }

  // ==========================================
  // PULL (Serveur → Local)
  // ==========================================

  // Inside sync_service.dart
  static Future<_SyncOpResult> _pullServerChanges(String userId,
      {String? since}) async {
    int pulled = 0;
    int conflicts = 0;

    try {
      final items = await ApiService.pullItems(since: since);

      for (final itemJson in items) {
        final serverItem = VaultItem.fromJson(itemJson, userId);
        final table = serverItem.type.tableName;

        // 1. Search using server_id (UUID), NOT local id
        final existing = await DBService.query(
          table,
          where: 'server_id = ?',
          whereArgs: [serverItem.serverId],
        );

        if (existing.isEmpty) {
          // 2. New Item: Convert to Map and remove 'id'
          // This lets SQLite generate a local Integer ID (1, 2, 3...)
          final dbData = serverItem.toDb();
          dbData.remove('id');

          await DBService.insert(table, dbData);
          pulled++;
        } else {
          // 3. Existing Item: Compare versions
          final localItem = VaultItem.fromDb(existing[0], serverItem.type);

          if (serverItem.version > localItem.version) {
            // Update local using the local Integer ID
            await DBService.update(
              table,
              serverItem.toDb(),
              where: 'id = ?',
              whereArgs: [localItem.id],
            );
            pulled++;
          } else if (serverItem.version < localItem.version) {
            conflicts++;
            await _handleConflict(localItem, table);
          }
        }
      }
    } catch (e) {
      print('❌ Error pulling: $e');
      rethrow;
    }
    return _SyncOpResult(itemsCount: pulled, conflicts: conflicts);
  }
  // ==========================================
  // GESTION DES CONFLITS
  // ==========================================

  static Future<void> _handleConflict(VaultItem item, String table) async {
    // Stratégie simple: last-write-wins (serveur gagne)
    // Tu peux implémenter une stratégie plus complexe:
    // - demander à l'utilisateur
    // - créer une copie locale
    // - merger les données

    print('⚠️ Conflit détecté pour item ${item.id}');

    // Pour l'instant: marquer comme conflit et garder local
    await DBService.update(
      table,
      {'sync_status': 2}, // 2 = conflict
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // ==========================================
  // HELPERS API
  // ==========================================

  static Future<Map<String, dynamic>> _createItemOnServer(
      VaultItem item) async {
    final parts = _splitEncryptedData(item.encryptedData);
    final itemJson = item.toJson(); // 👈 Use the model's built-in JSON logic

    return await ApiService.createItem(
      itemType: item.type == VaultItemType.file ? 'document' : item.type.name,
      ciphertextB64: parts['cipher']!,
      nonceB64: parts['nonce']!,
      tagB64: parts['tag']!,
      metaCiphertextB64: itemJson[
          'meta_ciphertext_b64'], // 👈 Includes title/eventDate automatically
      size: item.size ?? 0,
      version: item.version,
      deviceId: item.deviceId,
    );
  }

  static Future<void> _updateItemOnServer(VaultItem item) async {
    final parts = _splitEncryptedData(item.encryptedData);
    final itemJson = item.toJson();

    await ApiService.updateItem(
      itemId: item.serverId!,
      updates: {
        'ciphertext_b64': parts['cipher'],
        'nonce_b64': parts['nonce'],
        'tag_b64': parts['tag'],
        'meta_ciphertext_b64': itemJson['meta_ciphertext_b64'], // 👈 Fixed
        'size': item.size ?? 0,
        'version': item.version + 1,
        'client_updated_at': item.updatedAt.toIso8601String(),
      },
    );
  }

  // ==========================================
  // UTILITAIRES
  // ==========================================

  static Map<String, String> _splitEncryptedData(String base64Data) {
    try {
      // Use your unpack utility to get the REAL nonce and tag
      final parts = CryptoService.unpackCombinedB64(base64Data);

      return {
        'nonce': base64Encode(parts.nonce),
        'cipher': base64Encode(parts.ciphertext),
        'tag': base64Encode(parts.tag),
      };
    } catch (e) {
      print('⚠️ Data split error: $e');
      return {
        'nonce': 'AAAA',
        'cipher': base64Data,
        'tag': 'AAAA',
      };
    }
  }

  static VaultItemType _getItemTypeFromTable(String table) {
    switch (table) {
      case 'files':
        return VaultItemType.file;
      case 'contacts':
        return VaultItemType.contact;
      case 'events':
        return VaultItemType.event;
      case 'notes':
        return VaultItemType.note;
      default:
        throw Exception('Table inconnue: $table');
    }
  }

  static Future<bool> _hasConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // SYNC AUTOMATIQUE
  // ==========================================

  static Timer? _autoSyncTimer;

  /// Démarre la synchronisation automatique
  static void startAutoSync({
    required String userId,
    Duration interval = const Duration(minutes: 5),
  }) {
    _autoSyncTimer?.cancel();

    _autoSyncTimer = Timer.periodic(interval, (timer) async {
      if (await _hasConnection()) {
        print('🔄 Auto-sync...');
        await sync(userId: userId);
      }
    });

    print('✅ Auto-sync activée (intervalle: $interval)');
  }

  /// Arrête la synchronisation automatique
  static void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    print('⏸️ Auto-sync désactivée');
  }

  // ==========================================
  // NETTOYAGE
  // ==========================================

  static Future<void> cleanupDeletedItems(String userId) async {
    final tables = [
      DBService.tableFiles,
      DBService.tableContacts,
      DBService.tableEvents,
      DBService.tableNotes,
    ];

    for (final table in tables) {
      await DBService.cleanDeletedItems(table, userId);
    }

    print('🧹 Items supprimés nettoyés');
  }

  static void dispose() {
    stopAutoSync();
    // DELETE THIS LINE: _syncController.close();
    // We keep the stream open because this is a static service used globally.
  }
}

// ==========================================
// CLASSES DE DONNÉES
// ==========================================

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  conflict,
}

class SyncResult {
  final bool success;
  final String message;
  final int itemsPushed;
  final int itemsPulled;
  final int conflicts;
  final DateTime? timestamp;

  SyncResult({
    required this.success,
    required this.message,
    this.itemsPushed = 0,
    this.itemsPulled = 0,
    this.conflicts = 0,
    this.timestamp,
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, push: $itemsPushed, pull: $itemsPulled, conflicts: $conflicts)';
  }
}

class _SyncOpResult {
  final int itemsCount;
  final int conflicts;

  _SyncOpResult({
    required this.itemsCount,
    this.conflicts = 0,
  });
}
