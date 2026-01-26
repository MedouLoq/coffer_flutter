import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';

// Pour le web
import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

/// Service de base de données unifié
/// - SQLite pour mobile/desktop
/// - IndexedDB pour web
/// - Tables: files, contacts, events, notes
class DBService {
  static sqflite.Database? _database;
  static idb.Database? _webDb;
  
  static const String dbName = 'vault_secure.db';
  static const int dbVersion = 3;

  // Noms des tables
  static const String tableFiles = 'files';
  static const String tableContacts = 'contacts';
  static const String tableEvents = 'events';
  static const String tableNotes = 'notes';

  // ==========================================
  // INITIALISATION
  // ==========================================

  static Future<sqflite.Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Utilisez webDatabase pour le web');
    }
    _database ??= await _initSQLite();
    return _database!;
  }

  static Future<idb.Database> get webDatabase async {
    if (!kIsWeb) {
      throw UnsupportedError('Utilisez database pour mobile');
    }
    _webDb ??= await _initIndexedDB();
    return _webDb!;
  }

  // ==========================================
  // SQLITE (Mobile/Desktop)
  // ==========================================

  static Future<sqflite.Database> _initSQLite() async {
    final path = join(await sqflite.getDatabasesPath(), dbName);

    return await sqflite.openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, version) async {
        await _createSQLiteTables(db);
        print('✅ Base SQLite créée (v$version)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('🔄 Mise à jour SQLite: v$oldVersion -> v$newVersion');
        
        // Migration progressive
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $tableFiles ADD COLUMN server_id TEXT');
          await db.execute('ALTER TABLE $tableFiles ADD COLUMN sync_status INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE $tableFiles ADD COLUMN deleted INTEGER DEFAULT 0');
        }
        
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $tableFiles ADD COLUMN version INTEGER DEFAULT 1');
          await db.execute('ALTER TABLE $tableFiles ADD COLUMN device_id TEXT');
        }
        
        print('✅ Migration terminée');
      },
    );
  }

  static Future<void> _createSQLiteTables(sqflite.Database db) async {
    // Table FILES
    await db.execute('''
      CREATE TABLE $tableFiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        server_id TEXT,
        filename TEXT NOT NULL,
        data TEXT NOT NULL,
        category TEXT NOT NULL,
        size INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        device_id TEXT
      )
    ''');

    // Table CONTACTS
    await db.execute('''
      CREATE TABLE $tableContacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        server_id TEXT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1
      )
    ''');

    // Table EVENTS
    await db.execute('''
      CREATE TABLE $tableEvents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        server_id TEXT,
        event_date TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1
      )
    ''');

    // Table NOTES
    await db.execute('''
      CREATE TABLE $tableNotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        server_id TEXT,
        title TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1
      )
    ''');

    // Index pour performance
    await db.execute('CREATE INDEX idx_files_user ON $tableFiles(user_id)');
    await db.execute('CREATE INDEX idx_files_sync ON $tableFiles(sync_status)');
    await db.execute('CREATE INDEX idx_contacts_user ON $tableContacts(user_id)');
    await db.execute('CREATE INDEX idx_events_user ON $tableEvents(user_id)');
    await db.execute('CREATE INDEX idx_notes_user ON $tableNotes(user_id)');
  }

  // ==========================================
  // INDEXEDDB (Web)
  // ==========================================

  static Future<idb.Database> _initIndexedDB() async {
    final idbFactory = getIdbFactory()!;

    return await idbFactory.open(
      'vault_secure_idb',
      version: dbVersion,
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.database;

        // Créer les stores si nécessaire
        _createIndexedDBStore(db, tableFiles);
        _createIndexedDBStore(db, tableContacts);
        _createIndexedDBStore(db, tableEvents);
        _createIndexedDBStore(db, tableNotes);

        print('✅ IndexedDB créée (v${event.newVersion})');
      },
    );
  }

  static void _createIndexedDBStore(idb.Database db, String storeName) {
    if (!db.objectStoreNames.contains(storeName)) {
      final store = db.createObjectStore(
        storeName,
        keyPath: 'id',
        autoIncrement: true,
      );
      
      // Index
      store.createIndex('user_id', 'user_id', unique: false);
      store.createIndex('sync_status', 'sync_status', unique: false);
      store.createIndex('updated_at', 'updated_at', unique: false);
    }
  }

  // ==========================================
  // API UNIFIÉE - INSERT
  // ==========================================

  static Future<int> insert(String table, Map<String, dynamic> values) async {
    // Ajouter timestamps automatiquement
    final now = DateTime.now().toIso8601String();
    values['created_at'] ??= now;
    values['updated_at'] = now;

    if (kIsWeb) {
      final db = await webDatabase;
      final txn = db.transaction(table, idb.idbModeReadWrite);
      final store = txn.objectStore(table);
      final key = await store.add(values);
      await txn.completed;
      return key as int;
    } else {
      final db = await database;
      return await db.insert(table, values);
    }
  }

  // ==========================================
  // API UNIFIÉE - QUERY
  // ==========================================

  static Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    if (kIsWeb) {
      final db = await webDatabase;
      final txn = db.transaction(table, idb.idbModeReadOnly);
      final store = txn.objectStore(table);

      final records = await store.getAll();
      await txn.completed;

      List<Map<String, dynamic>> results = records.map((record) {
        return Map<String, dynamic>.from(record as Map);
      }).toList();

      // Filtrage manuel (where clause)
      if (where != null && whereArgs != null) {
        results = _filterResults(results, where, whereArgs);
      }

      // Tri manuel
      if (orderBy != null) {
        results = _sortResults(results, orderBy);
      }

      return results;
    } else {
      final db = await database;
      return await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
      );
    }
  }

  // ==========================================
  // API UNIFIÉE - UPDATE
  // ==========================================

  static Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    values['updated_at'] = DateTime.now().toIso8601String();

    if (kIsWeb) {
      final db = await webDatabase;
      
      if (where == 'id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
        final id = whereArgs[0];
        final txn = db.transaction(table, idb.idbModeReadWrite);
        final store = txn.objectStore(table);

        final existing = await store.getObject(id);
        if (existing != null) {
          final updated = Map<String, dynamic>.from(existing as Map);
          updated.addAll(values);
          await store.put(updated, id);
        }

        await txn.completed;
        return 1;
      }
      return 0;
    } else {
      final db = await database;
      return await db.update(table, values, where: where, whereArgs: whereArgs);
    }
  }

  // ==========================================
  // API UNIFIÉE - DELETE
  // ==========================================

  static Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (kIsWeb) {
      final db = await webDatabase;

      if (where == null) {
        // Supprimer tous
        final txn = db.transaction(table, idb.idbModeReadWrite);
        final store = txn.objectStore(table);
        await store.clear();
        await txn.completed;
        return 1;
      } else if (where == 'id = ?' && whereArgs != null) {
        final id = whereArgs[0];
        final txn = db.transaction(table, idb.idbModeReadWrite);
        final store = txn.objectStore(table);
        await store.delete(id);
        await txn.completed;
        return 1;
      }
      return 0;
    } else {
      final db = await database;
      return await db.delete(table, where: where, whereArgs: whereArgs);
    }
  }

  // ==========================================
  // MÉTHODES SPÉCIFIQUES
  // ==========================================

  /// Marque un item comme supprimé (soft delete)
  static Future<int> markAsDeleted(String table, int id) async {
    return await update(
      table,
      {'deleted': 1, 'sync_status': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Récupère les items à synchroniser
  static Future<List<Map<String, dynamic>>> getPendingSync(String table, String userId) async {
    return await query(
      table,
      where: 'user_id = ? AND sync_status = ?',
      whereArgs: [userId, 1],
    );
  }

  /// Nettoie les items supprimés (après sync)
  static Future<void> cleanDeletedItems(String table, String userId) async {
    await delete(
      table,
      where: 'user_id = ? AND deleted = ? AND sync_status = ?',
      whereArgs: [userId, 1, 0],
    );
  }

  // ==========================================
  // UTILITAIRES INDEXEDDB
  // ==========================================

  static List<Map<String, dynamic>> _filterResults(
    List<Map<String, dynamic>> results,
    String where,
    List<dynamic> whereArgs,
  ) {
    // Parsing simple de where clause
    if (where.contains('user_id = ?')) {
      final userId = whereArgs[0];
      return results.where((r) => r['user_id'] == userId).toList();
    }
    
    if (where.contains('sync_status = ?')) {
      final status = whereArgs.last;
      return results.where((r) => r['sync_status'] == status).toList();
    }

    return results;
  }

  static List<Map<String, dynamic>> _sortResults(
    List<Map<String, dynamic>> results,
    String orderBy,
  ) {
    if (orderBy.contains('updated_at DESC')) {
      results.sort((a, b) {
        final dateA = DateTime.tryParse(a['updated_at'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['updated_at'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
    } else if (orderBy.contains('created_at DESC')) {
      results.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
    }
    return results;
  }

  // ==========================================
  // DEBUG
  // ==========================================

  static Future<void> printStats() async {
    print('📊 Statistiques DB:');
    for (final table in [tableFiles, tableContacts, tableEvents, tableNotes]) {
      final count = (await query(table)).length;
      print('   - $table: $count items');
    }
  }
}