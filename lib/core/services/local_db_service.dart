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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _configureDB,
    );
  }

  Future<void> _configureDB(Database db) async {
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA cache_size = -2000');
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Table for SESSIONS with 'end_time'
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        end_time TEXT, 
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

  // Handle migration from V1 to V2
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE sessions ADD COLUMN end_time TEXT");
    }
  }

  // ==========================================
  // SESSION MANAGEMENT
  // ==========================================

  Future<int> createSession() async {
    final db = await database;
    // Create new session. 'end_time' is NULL by default (meaning Active)
    return await db.insert('sessions', {
      'timestamp': DateTime.now().toIso8601String(),
      'distance': 0.0,
      'duration': 0,
    });
  }

  Future<int?> getActiveSessionId() async {
    final db = await database;

    final maps = await db.query(
      'sessions',
      where: 'end_time IS NULL',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    }
    return null;
  }

  // 🛠️ NEW: Explicitly close the session
  Future<void> closeSession(int sessionId, double distance, int duration) async {
    final db = await database;
    await db.update(
      'sessions',
      {
        'distance': distance,
        'duration': duration,
        'end_time': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
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

  Future<void> deleteSession(int sessionId) async {
    try {
      final db = await database;
      await db.delete('points', where: 'session_id = ?', whereArgs: [sessionId]);
      await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
    } catch (e) {
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

  // ==========================================
  // POINTS MANAGEMENT (Optimized)
  // ==========================================

  Future<void> insertPointsBatch(
      List<LocationPoint> points,
      int sessionId,
      ) async {
    if (points.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (var point in points) {
      // 🛠️ Create a copy of the map to inject session_id safely
      final Map<String, dynamic> data = Map.from(point.toJson());
      data['session_id'] = sessionId;

      batch.insert(
        'points',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRaw(int limit) async {
    final db = await database;
    return await db.query(
      'points',
      columns: ['id', 'lat', 'lon', 'speed', 'accuracy', 'timestamp'],
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> clearPointsByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();

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