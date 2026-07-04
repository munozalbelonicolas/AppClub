import 'package:flutter/foundation.dart';

/// Centralized logger for the application.
/// In debug mode, logs are printed. In release mode, they are suppressed.
/// This replaces all scattered debugPrint() calls with a single,
/// configurable logging mechanism.
class AppLogger {
  AppLogger._();

  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('$prefix$message');
    }
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('❌ ${prefix}ERROR: $message');
      if (error != null) debugPrint('  → $error');
      if (stackTrace != null) debugPrint('  → $stackTrace');
    }
    // In production, this is where you'd send to Crashlytics/Sentry:
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('⚠️ ${prefix}WARNING: $message');
    }
  }

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('ℹ️ $prefix$message');
    }
  }
}
