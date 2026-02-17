import 'package:flutter/foundation.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/data/models/location_point.dart';

/// Manages buffered database writes for location points
class DatabaseBuffer {
  final List<LocationPoint> _pointBuffer = [];
  int? _currentSessionId;

  static const int minBufferSize = 20;
  static const int maxBufferLimit = 1000;

  void setSessionId(int? sessionId) {
    _currentSessionId = sessionId;
  }

  void addPoint(LocationPoint point) {
    if (_currentSessionId == null) return;
    _pointBuffer.add(point);
  }

  Future<void> flushIfNeeded() async {
    if (_pointBuffer.length >= minBufferSize) {
      await flush();
    }
  }

  Future<void> flush() async {
    if (_pointBuffer.isEmpty || _currentSessionId == null) return;

    final batch = List<LocationPoint>.from(_pointBuffer);
    _pointBuffer.clear();

    try {
      await LocalDatabase.instance.insertPointsBatch(
        batch,
        _currentSessionId!,
      );
      debugPrint("✅ Flushed ${batch.length} points to DB");
    } catch (e) {
      debugPrint('❌ Failed to save points to DB: $e');

      // Re-add with overflow protection
      if (_pointBuffer.length + batch.length <= maxBufferLimit) {
        _pointBuffer.insertAll(0, batch);
      } else {
        debugPrint('⚠️ Buffer overflow! Dropped ${batch.length} points.');
      }
    }
  }

  int get bufferSize => _pointBuffer.length;
  bool get hasBufferedData => _pointBuffer.isNotEmpty;

  void clear() {
    _pointBuffer.clear();
  }
}