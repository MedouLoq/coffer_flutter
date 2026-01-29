import 'dart:convert';
import '../services/crypto_service.dart';

/// Types d'items dans le vault
enum VaultItemType {
  file,
  contact,
  event,
  note;

  String get tableName {
    switch (this) {
      case VaultItemType.file:
        return 'files';
      case VaultItemType.contact:
        return 'contacts';
      case VaultItemType.event:
        return 'events';
      case VaultItemType.note:
        return 'notes';
    }
  }
}

/// Statut de synchronisation
enum SyncStatus {
  synced(0), // Synchronisé avec le serveur
  pending(1), // En attente de sync
  conflict(2); // Conflit détecté

  final int value;
  const SyncStatus(this.value);

  static SyncStatus fromInt(int value) {
    return SyncStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => SyncStatus.synced,
    );
  }
}

/// Modèle unifié pour tous les items du vault
class VaultItem {
  final int? id; // ID local (SQLite/IndexedDB)
  final String? serverId; // ID sur le serveur (UUID)
  final String userId; // ID de l'utilisateur propriétaire
  final VaultItemType type; // Type d'item

  // Données chiffrées
  final String encryptedData; // Contenu chiffré (JSON ou bytes en base64)

  // Métadonnées (peuvent être chiffrées ou non selon les besoins)
  final String? filename; // Pour les fichiers
  final String? category; // Pour les fichiers
  final int? size; // Taille en bytes
  final String? title; // Pour les notes
  final String? eventDate; // Pour les événements

  // Synchronisation
  final SyncStatus syncStatus;
  final bool deleted;
  final int version; // Pour résolution de conflits
  final String? deviceId;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultItem({
    this.id,
    this.serverId,
    required this.userId,
    required this.type,
    required this.encryptedData,
    this.filename,
    this.category,
    this.size,
    this.title,
    this.eventDate,
    this.syncStatus = SyncStatus.pending,
    this.deleted = false,
    this.version = 1,
    this.deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ==========================================
  // CONVERSION DB <-> MODÈLE
  // ==========================================

  /// Crée un VaultItem depuis une ligne de DB
  factory VaultItem.fromDb(Map<String, dynamic> map, VaultItemType type) {
    return VaultItem(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      userId: map['user_id'] as String,
      type: type,
      encryptedData: map['data'] as String,
      filename: map['filename'] as String?,
      category: map['category'] as String?,
      size: map['size'] as int?,
      title: map['title'] as String?,
      eventDate: map['event_date'] as String?,
      syncStatus: SyncStatus.fromInt(map['sync_status'] as int? ?? 0),
      deleted: (map['deleted'] as int? ?? 0) == 1,
      version: map['version'] as int? ?? 1,
      deviceId: map['device_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convertit en Map pour insertion DB
  // Inside vault_item_model.dart
  Map<String, dynamic> toDb() {
    // 1. Mandatory base fields for ALL tables
    final map = {
      if (id != null) 'id': id,
      'user_id': userId, // 👈 This fixes the NOT NULL constraint error
      'server_id': serverId,
      'data': encryptedData,
      'sync_status': syncStatus.value,
      'deleted': deleted ? 1 : 0,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    // 2. Add specific metadata based on the table schema
    if (type == VaultItemType.file) {
      map['filename'] = filename;
      map['category'] = category;
      map['size'] = size;
      map['device_id'] = deviceId;
    } else if (type == VaultItemType.event) {
      map['event_date'] =
          eventDate; // 👈 Correct column name for 'events' table
    } else if (type == VaultItemType.note) {
      map['title'] = title; // 👈 Correct column name for 'notes' table
    }

    return map;
  }

  // ==========================================
  // CONVERSION API (SERVEUR)
  // ==========================================

  /// Convertit en JSON pour l'API Django
  Map<String, dynamic> toJson() {
    return {
      if (serverId != null) 'id': serverId,
      'item_type': type.name,
      'ciphertext_b64': encryptedData,
      'nonce_b64': '', // Géré dans le service crypto
      'tag_b64': '', // Géré dans le service crypto
      'meta_ciphertext_b64': _encryptedMetadata(),
      'size': size ?? 0,
      'version': version,
      'deleted': deleted,
      'client_updated_at': updatedAt.toIso8601String(),
      if (deviceId != null) 'device_id': deviceId,
    };
  }

  /// Crée depuis la réponse de l'API
  factory VaultItem.fromJson(Map<String, dynamic> json, String userId) {
    final typeStr = json['item_type'] as String;
    final type = VaultItemType.values.firstWhere(
      (t) => t.name == typeStr || (t.name == 'file' && typeStr == 'document'),
      orElse: () => VaultItemType.file,
    );

    // 1. Django stores metadata in 'meta_ciphertext_b64'
    String? filename = json['filename']; // Try direct first
    String? category = json['category'];
    String? title = json['title'];
    String? eventDate = json['event_date'];
    int? size = json['size'];

    // 2. If null, try to extract from the metadata blob
    final metaBlob = json['meta_ciphertext_b64'] as String?;
    if (filename == null && metaBlob != null && metaBlob.isNotEmpty) {
      try {
        // For now, metadata is stored as a raw JSON string in that field
        final decodedMeta = jsonDecode(metaBlob);
        filename = decodedMeta['filename'];
        category = decodedMeta['category'];
        title ??= decodedMeta['title']; // 👈 Added
        eventDate ??= decodedMeta['event_date']; // 👈 Added
      } catch (e) {
        print("⚠️ Could not parse metadata blob: $e");
      }
    }
    String encryptedData = json['ciphertext_b64'] ?? '';
    if (json['nonce_b64'] != null && json['tag_b64'] != null) {
      try {
        encryptedData = CryptoService.packCombinedB64(
          nonce: base64Decode(json['nonce_b64']),
          ciphertext: base64Decode(json['ciphertext_b64']),
          tag: base64Decode(json['tag_b64']),
        );
      } catch (e) {
        print("⚠️ Error packing pulled data: $e");
      }
    }

    return VaultItem(
      serverId: json['id'] as String?,
      userId: userId,
      type: type,
      encryptedData: encryptedData, // Now has the full data!
      filename: filename ?? 'Unknown File',
      category: category ?? 'General',
      size: size ?? 0,
      title: title, // 👈 Don't forget to pass these to the constructor
      eventDate: eventDate,
      syncStatus: SyncStatus.synced,
      version: json['version'] ?? 1,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
  // ==========================================
  // HELPERS
  // ==========================================

  /// Copie avec modifications
  VaultItem copyWith({
    int? id,
    String? serverId,
    String? userId,
    VaultItemType? type,
    String? encryptedData,
    String? filename,
    String? category,
    int? size,
    String? title,
    String? eventDate,
    SyncStatus? syncStatus,
    bool? deleted,
    int? version,
    String? deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      encryptedData: encryptedData ?? this.encryptedData,
      filename: filename ?? this.filename,
      category: category ?? this.category,
      size: size ?? this.size,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      syncStatus: syncStatus ?? this.syncStatus,
      deleted: deleted ?? this.deleted,
      version: version ?? this.version,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Marque comme nécessitant une sync
  VaultItem markForSync() {
    return copyWith(
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
  }

  /// Marque comme synchronisé
  VaultItem markSynced(String serverId) {
    return copyWith(
      serverId: serverId,
      syncStatus: SyncStatus.synced,
    );
  }

  /// Métadonnées chiffrées (pour l'API)
  String _encryptedMetadata() {
    final meta = {
      if (filename != null) 'filename': filename,
      if (category != null) 'category': category,
      if (title != null) 'title': title,
      if (eventDate != null) 'event_date': eventDate,
    };
    return jsonEncode(meta);
  }

  @override
  String toString() {
    return 'VaultItem(id: $id, type: ${type.name}, sync: ${syncStatus.name})';
  }
}

/// Extension pour listes
extension VaultItemListExtension on List<VaultItem> {
  /// Filtre les items non supprimés
  List<VaultItem> get active => where((item) => !item.deleted).toList();

  /// Filtre les items à synchroniser
  List<VaultItem> get pendingSync =>
      where((item) => item.syncStatus == SyncStatus.pending).toList();

  /// Trie par date de modification (plus récent en premier)
  List<VaultItem> sortByDate() {
    final copy = List<VaultItem>.from(this);
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }
}
