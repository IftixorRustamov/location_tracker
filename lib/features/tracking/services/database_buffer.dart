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
    } catch (e) {
      if (_pointBuffer.length + batch.length <= maxBufferLimit) {
        _pointBuffer.insertAll(0, batch);
      }
    }
  }

  int get bufferSize => _pointBuffer.length;
  bool get hasBufferedData => _pointBuffer.isNotEmpty;

  void clear() {
    _pointBuffer.clear();
  }
}