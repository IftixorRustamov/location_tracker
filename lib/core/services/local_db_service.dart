import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:location_tracker/data/models/location_point.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tracker_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _configureDB, // Hook up the configuration
    );
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      final db = await database;

      await db.delete(
        'points',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      // Delete session
      await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);

      debugPrint("✅ Deleted session $sessionId");
    } catch (e) {
      debugPrint("❌ Failed to delete session: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await database;
    return await db.query('sessions', orderBy: 'id DESC');
  }

  Future<List<LocationPoint>> getPointsForSession(int sessionId) async {
    final db = await database;
    final result = await db.query(
      'points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return result.map((json) => LocationPoint.fromJson(json)).toList();
  }

  /// 🛠️ FIXED: Use rawQuery for journal_mode because it returns a result row
  Future<void> _configureDB(Database db) async {
    // 1. WAL mode returns "wal", so we MUST use rawQuery
    await db.rawQuery('PRAGMA journal_mode = WAL');

    // 2. These commands return nothing, so execute is fine
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA cache_size = -2000');

    debugPrint("✅ Database configured with optimizations (WAL + Memory)");
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Table for SESSIONS
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        distance REAL DEFAULT 0.0,
        duration INTEGER DEFAULT 0
      )
    ''');

    // 2. Table for POINTS
    await db.execute('''
      CREATE TABLE points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL, 
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        speed REAL NOT NULL,
        accuracy REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_session_id ON points (session_id)');
    await db.execute('CREATE INDEX idx_timestamp ON points (timestamp)');
  }

  // ==========================================
  // SESSION MANAGEMENT
  // ==========================================

  Future<int> createSession() async {
    final db = await database;
    return await db.insert('sessions', {
      'timestamp': DateTime.now().toIso8601String(),
      'distance': 0.0,
      'duration': 0,
    });
  }

  Future<int?> getActiveSessionId() async {
    final db = await database;
    final maps = await db.query('sessions', orderBy: 'id DESC', limit: 1);

    if (maps.isNotEmpty) {
      if (maps.first['distance'] == null ||
          (maps.first['distance'] as num) == 0) {
        return maps.first['id'] as int;
      }
    }
    return null;
  }

  Future<void> updateSessionStats(
    int sessionId,
    double distance,
    int duration,
  ) async {
    final db = await database;
    await db.update(
      'sessions',
      {'distance': distance, 'duration': duration},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ==========================================
  // POINTS MANAGEMENT (Optimized)
  // ==========================================

  /// Insert multiple points in a single transaction
  Future<void> insertPointsBatch(
    List<LocationPoint> points,
    int sessionId,
  ) async {
    if (points.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (var point in points) {
      final data = point.toJson();
      data['session_id'] = sessionId;
      batch.insert(
        'points',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get raw unsynced points for the Isolate
  Future<List<Map<String, dynamic>>> getUnsyncedRaw(int limit) async {
    final db = await database;
    return await db.query(
      'points',
      columns: ['id', 'lat', 'lon', 'speed', 'accuracy', 'timestamp'],
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  /// Batch delete points by ID
  Future<void> clearPointsByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    // Chunking to avoid SQLite variable limits (999)
    const chunkSize = 100;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      final chunk = ids.sublist(i, end);

      batch.delete(
        'points',
        where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
    }

    await batch.commit(noResult: true);
  }
}
