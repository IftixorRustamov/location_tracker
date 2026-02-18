/// Utility class for formatting time and duration values
class TimeFormatter {
  TimeFormatter._();

  /// Format duration as HH:MM:SS or MM:SS
  ///
  /// Examples:
  /// - 45 seconds → "00:45"
  /// - 2 minutes 30 seconds → "02:30"
  /// - 1 hour 15 minutes 30 seconds → "01:15:30"
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final hoursStr = hours.toString().padLeft(2, '0');
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hoursStr:$minutesStr:$secondsStr';
    } else {
      return '$minutesStr:$secondsStr';
    }
  }

  /// Format duration in a human-readable way
  ///
  /// Examples:
  /// - 45 seconds → "45 seconds"
  /// - 2 minutes 30 seconds → "2 minutes"
  /// - 1 hour 15 minutes → "1 hour 15 minutes"
  static String formatDurationHumanReadable(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours ${_pluralize('hour', hours)} $minutes ${_pluralize('minute', minutes)}';
      }
      return '$hours ${_pluralize('hour', hours)}';
    } else if (minutes > 0) {
      return '$minutes ${_pluralize('minute', minutes)}';
    } else {
      return '$seconds ${_pluralize('second', seconds)}';
    }
  }

  /// Format time ago from timestamp
  ///
  /// Examples:
  /// - 5 seconds ago → "5s ago"
  /// - 2 minutes ago → "2m ago"
  /// - 1 hour ago → "1h ago"
  /// - 2 days ago → "2d ago"
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Format timestamp from ISO8601 string
  ///
  /// Example: "2024-02-17T10:30:00Z" → "5s ago"
  static String formatTimeAgoFromString(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return formatTimeAgo(dateTime);
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Check if timestamp is stale (older than threshold)
  static bool isStale(String timestamp, Duration threshold) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final difference = DateTime.now().toUtc().difference(dateTime);
      return difference > threshold;
    } catch (e) {
      return false;
    }
  }

  /// Format time as HH:MM:SS
  static String formatTime(DateTime dateTime) {
    final hours = dateTime.hour.toString().padLeft(2, '0');
    final minutes = dateTime.minute.toString().padLeft(2, '0');
    final seconds = dateTime.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Format date as YYYY-MM-DD
  static String formatDate(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Format date and time as YYYY-MM-DD HH:MM:SS
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${formatTime(dateTime)}';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static String _pluralize(String word, int count) {
    return count == 1 ? word : '${word}s';
  }
}