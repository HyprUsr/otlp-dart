import 'logger.dart';

/// LoggerProvider provides access to loggers.
abstract class LoggerProvider {
  /// Gets a logger with the given instrumentation scope.
  Logger getLogger(
    String name, {
    String? version,
  });

  /// Shuts down the logger provider and all associated components.
  Future<void> shutdown();

  /// Forces all pending logs to be exported.
  Future<void> forceFlush();
}
