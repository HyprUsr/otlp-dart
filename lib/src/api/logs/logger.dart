import '../../sdk/common/attribute.dart';
import 'severity.dart';

/// Logger is the interface for emitting log records.
abstract class Logger {
  /// Emits a log record.
  void log(
    Severity severity,
    String message, {
    Map<String, AttributeValue>? attributes,
    String? traceId,
    String? spanId,
    DateTime? timestamp,
  });

  /// Emits a trace level log.
  void trace(String message, {Map<String, AttributeValue>? attributes}) {
    log(Severity.trace, message, attributes: attributes);
  }

  /// Emits a debug level log.
  void debug(String message, {Map<String, AttributeValue>? attributes}) {
    log(Severity.debug, message, attributes: attributes);
  }

  /// Emits an info level log.
  void info(String message, {Map<String, AttributeValue>? attributes}) {
    log(Severity.info, message, attributes: attributes);
  }

  /// Emits a warn level log.
  void warn(String message, {Map<String, AttributeValue>? attributes}) {
    log(Severity.warn, message, attributes: attributes);
  }

  /// Emits an error level log.
  void error(String message, {Map<String, AttributeValue>? attributes}) {
    log(Severity.error, message, attributes: attributes);
  }

  /// Emits a fatal level log.
  void fatal(String message, {Map<String, AttributeValue>? attributes}) {
    log(Severity.fatal, message, attributes: attributes);
  }
}
