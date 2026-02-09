import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:location_tracker/data/models/location_point.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('tracker_v1.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE points (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          lat REAL,
          lon REAL,
          speed REAL,
          accuracy REAL,
          timestamp TEXT
        )
      ''');
        await db.execute('CREATE INDEX idx_timestamp ON points (timestamp)');
      },
    );
  }

  Future<int> insertPoint(LocationPoint point) async {
    final db = await database;
    return await db.insert(
      'points',
      point.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBatch(List<LocationPoint> points) async {
    final db = await database;
    final batch = db.batch();
    for (var point in points) {
      batch.insert('points', point.toJson());
    }
    await batch.commit(noResult: true);
  }

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

  Future<int> getCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM points');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
