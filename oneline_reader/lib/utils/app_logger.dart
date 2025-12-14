import 'package:flutter/foundation.dart';

/// Lightweight structured logger to replace ad-hoc prints.
class AppLogger {
  const AppLogger(this.scope);

  final String scope;

  void info(String message, {Map<String, Object?> context = const {}}) {
    _log('INFO', message, context);
  }

  void warn(String message, {Map<String, Object?> context = const {}}) {
    _log('WARN', message, context);
  }

  void error(String message, {Map<String, Object?> context = const {}}) {
    _log('ERROR', message, context);
  }

  void _log(String level, String message, Map<String, Object?> context) {
    final ts = DateTime.now().toIso8601String();
    final ctx = context.isEmpty ? '' : ' ${context.toString()}';
    debugPrint('[$ts][$scope][$level] $message$ctx');
  }
}
