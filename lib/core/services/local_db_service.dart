import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:location_tracker/data/models/location_point.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tracker_v2.db'); // Changed name to force new DB
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Table for SESSIONS (The "Header" of the trip)
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        distance REAL DEFAULT 0.0,
        duration INTEGER DEFAULT 0
      )
    ''');

    // 2. Table for POINTS (The "Data" of the trip)
    // We added 'session_id' to link points to a session
    await db.execute('''
      CREATE TABLE points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER, 
        lat REAL,
        lon REAL,
        speed REAL,
        accuracy REAL,
        timestamp TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_session_id ON points (session_id)');
  }

  // --- SESSION MANAGEMENT ---

  /// Creates a new session when you click "Start Tracking"
  /// Returns the new Session ID
  Future<int> createSession() async {
    final db = await database;
    return await db.insert('sessions', {
      'timestamp': DateTime.now().toIso8601String(),
      'distance': 0.0,
      'duration': 0,
    });
  }

  /// Get all sessions for the History Screen
  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await database;
    // Order by newest first (DESC)
    return await db.query('sessions', orderBy: 'id DESC');
  }

  /// Updates the final stats when you click "Stop Tracking"
  Future<void> updateSessionStats(int sessionId, double distance, int duration) async {
    final db = await database;
    await db.update(
      'sessions',
      {'distance': distance, 'duration': duration},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // --- POINTS MANAGEMENT ---

  /// Insert a point linked to a specific Session ID
  Future<int> insertPoint(LocationPoint point, int sessionId) async {
    final db = await database;

    // We convert the point to JSON, then add the session_id manually
    final data = point.toJson();
    data['session_id'] = sessionId; // <--- LINKING HAPPENS HERE

    return await db.insert(
      'points',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all points for a specific session (For the Map Screen)
  Future<List<LocationPoint>> getPointsForSession(int sessionId) async {
    final db = await database;
    final result = await db.query(
      'points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC', // Chronological order for the route line
    );

    return result.map((json) => LocationPoint.fromJson(json)).toList();
  }

  // --- SYNC / CLEANUP ---

  Future<List<Map<String, dynamic>>> getUnsyncedRaw(int limit) async {
    final db = await database;
    return await db.query('points', orderBy: 'id ASC', limit: limit);
  }

  Future<void> clearPointsByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.delete(
      'points',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }
}