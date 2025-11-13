import '../../api/logs/logger.dart';
import '../../api/logs/log_record.dart';
import '../../api/logs/severity.dart';
import '../../sdk/common/attribute.dart';
import '../../sdk/resource/resource.dart';
import 'log_processor.dart';

/// Implementation of the Logger interface.
class LoggerImpl implements Logger {
  final InstrumentationScope scope;
  final Resource resource;
  final LogRecordProcessor processor;

  LoggerImpl({
    required this.scope,
    required this.resource,
    required this.processor,
  });

  @override
  void log(
    Severity severity,
    String message, {
    Map<String, AttributeValue>? attributes,
    String? traceId,
    String? spanId,
    DateTime? timestamp,
  }) {
    final now = DateTime.now();
    final timeUnixNano = _dateTimeToNanos(timestamp ?? now);
    final observedTimeUnixNano = _dateTimeToNanos(now);

    final attrs = attributes != null
        ? attributes.entries.map((e) => Attribute(e.key, e.value)).toList()
        : <Attribute>[];

    final logRecord = LogRecord(
      timeUnixNano: timeUnixNano,
      observedTimeUnixNano: observedTimeUnixNano,
      severity: severity,
      body: message,
      scope: scope,
      resource: resource,
      attributes: attrs,
      traceId: traceId,
      spanId: spanId,
    );

    processor.onEmit(logRecord);
  }

  static int _dateTimeToNanos(DateTime dateTime) {
    return dateTime.microsecondsSinceEpoch * 1000;
  }
}
