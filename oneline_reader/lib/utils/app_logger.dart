import 'package:flutter/foundation.dart';

/// Lightweight logger shim to avoid crashes when logging is optional.
class AppLogger {
  final String scope;
  const AppLogger(this.scope);

  void info(String message, {Map<String, Object?>? context}) {
    debugPrint(_format('INFO', message, context));
  }

  void warn(String message, {Map<String, Object?>? context}) {
    debugPrint(_format('WARN', message, context));
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint(_format('ERROR', message, {
      if (error != null) 'error': error,
      if (stackTrace != null) 'stack': stackTrace.toString(),
    }));
  }

  String _format(String level, String message, Map<String, Object?>? ctx) {
    final ctxString = (ctx == null || ctx.isEmpty) ? '' : ' | $ctx';
    return '[$level][$scope] $message$ctxString';
  }
}

