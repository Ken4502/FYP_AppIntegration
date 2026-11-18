import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

enum LogSeverity { debug, info, warning, error }

enum LogCategory { iot, http, plant, auth, store, system }

class AppLogEntry {
  final String id;
  final DateTime timestamp;
  final LogSeverity severity;
  final LogCategory category;
  final String tag;
  final String message;
  final Map<String, dynamic>? metadata;

  AppLogEntry({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.category,
    required this.tag,
    required this.message,
    this.metadata,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get severityName => severity.name.toUpperCase();
  String get categoryName => category.name.toUpperCase();

  Color get categoryColor {
    switch (category) {
      case LogCategory.iot:
        return const Color(0xFF10B981); // Emerald
      case LogCategory.http:
        return const Color(0xFF3B82F6); // Blue
      case LogCategory.plant:
        return const Color(0xFF8B5CF6); // Purple
      case LogCategory.auth:
        return const Color(0xFFF59E0B); // Amber
      case LogCategory.store:
        return const Color(0xFFEC4899); // Pink
      case LogCategory.system:
        return const Color(0xFF6B7280); // Gray
    }
  }

  Color get severityColor {
    switch (severity) {
      case LogSeverity.debug:
        return Colors.grey.shade500;
      case LogSeverity.info:
        return const Color(0xFF2563EB);
      case LogSeverity.warning:
        return const Color(0xFFD97706);
      case LogSeverity.error:
        return const Color(0xFFDC2626);
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case LogCategory.iot:
        return Icons.sensors_rounded;
      case LogCategory.http:
        return Icons.http_rounded;
      case LogCategory.plant:
        return Icons.local_florist_rounded;
      case LogCategory.auth:
        return Icons.lock_person_rounded;
      case LogCategory.store:
        return Icons.shopping_bag_rounded;
      case LogCategory.system:
        return Icons.developer_board_rounded;
    }
  }

  @override
  String toString() {
    final metaStr = metadata != null && metadata!.isNotEmpty ? ' | Data: $metadata' : '';
    return '[$formattedTime][$severityName][$categoryName][$tag] $message$metaStr';
  }
}

/// Central App Logger Service for monitoring & debugging mobile app behaviour
class AppLoggerService extends ChangeNotifier {
  static final AppLoggerService _instance = AppLoggerService._internal();
  factory AppLoggerService() => _instance;

  AppLoggerService._internal() {
    // Initial system boot log
    info('SystemBoot', 'UrbanGreen Mobile App Monitoring initialized', category: LogCategory.system);
  }

  final List<AppLogEntry> _logs = [];
  final StreamController<AppLogEntry> _logStreamController = StreamController<AppLogEntry>.broadcast();

  List<AppLogEntry> get logs => List.unmodifiable(_logs);
  Stream<AppLogEntry> get logStream => _logStreamController.stream;

  /// Log a debug-level entry
  void debug(String tag, String message, {LogCategory category = LogCategory.system, Map<String, dynamic>? metadata}) {
    _addEntry(LogSeverity.debug, category, tag, message, metadata);
  }

  /// Log an info-level entry
  void info(String tag, String message, {LogCategory category = LogCategory.system, Map<String, dynamic>? metadata}) {
    _addEntry(LogSeverity.info, category, tag, message, metadata);
  }

  /// Log a warning-level entry
  void warning(String tag, String message, {LogCategory category = LogCategory.system, Map<String, dynamic>? metadata}) {
    _addEntry(LogSeverity.warning, category, tag, message, metadata);
  }

  /// Log an error-level entry
  void error(String tag, String message, {LogCategory category = LogCategory.system, Map<String, dynamic>? metadata, Object? error, StackTrace? stackTrace}) {
    final combinedMeta = <String, dynamic>{
      if (metadata != null) ...metadata,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString().split('\n').take(3).join(' | '),
    };
    _addEntry(LogSeverity.error, category, tag, message, combinedMeta.isEmpty ? null : combinedMeta);
  }

  void _addEntry(LogSeverity severity, LogCategory category, String tag, String message, Map<String, dynamic>? metadata) {
    final entry = AppLogEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      severity: severity,
      category: category,
      tag: tag,
      message: message,
      metadata: metadata,
    );

    _logs.insert(0, entry);
    if (_logs.length > 500) {
      _logs.removeLast();
    }

    // Output to System Logcat / Developer Console
    developer.log(
      entry.toString(),
      name: 'urban.green.${category.name}',
      time: entry.timestamp,
    );

    _logStreamController.add(entry);
    notifyListeners();
  }

  /// Clear all stored logs
  void clear() {
    _logs.clear();
    info('System', 'Activity monitor log buffer cleared', category: LogCategory.system);
    notifyListeners();
  }

  /// Filter logs by category & search query
  List<AppLogEntry> filter({LogCategory? category, LogSeverity? severity, String query = ''}) {
    return _logs.where((entry) {
      if (category != null && entry.category != category) return false;
      if (severity != null && entry.severity != severity) return false;
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        final matchTag = entry.tag.toLowerCase().contains(q);
        final matchMsg = entry.message.toLowerCase().contains(q);
        final matchCat = entry.categoryName.toLowerCase().contains(q);
        return matchTag || matchMsg || matchCat;
      }
      return true;
    }).toList();
  }

  /// Export logs as plain text export string
  String exportAsText() {
    return _logs.reversed.map((e) => e.toString()).join('\n');
  }
}
