import '../../sdk/common/attribute.dart';
import '../../sdk/resource/resource.dart';
import 'severity.dart';

/// LogRecord represents a single log entry.
class LogRecord {
  final int timeUnixNano;
  final int observedTimeUnixNano;
  final Severity severity;
  final String body;
  final List<Attribute> attributes;
  final int droppedAttributesCount;
  final int flags;
  final String? traceId;
  final String? spanId;

  final InstrumentationScope scope;
  final Resource resource;

  LogRecord({
    required this.timeUnixNano,
    required this.observedTimeUnixNano,
    required this.severity,
    required this.body,
    required this.scope,
    required this.resource,
    List<Attribute>? attributes,
    this.droppedAttributesCount = 0,
    this.flags = 0,
    this.traceId,
    this.spanId,
  }) : attributes = attributes ?? [];

  Map<String, dynamic> toJson() => {
        'timeUnixNano': timeUnixNano.toString(),
        'observedTimeUnixNano': observedTimeUnixNano.toString(),
        'severityNumber': severity.value,
        'severityText': severity.text,
        'body': {'stringValue': body},
        'attributes': attributes.map((a) => a.toJson()).toList(),
        if (droppedAttributesCount > 0)
          'droppedAttributesCount': droppedAttributesCount,
        'flags': flags,
        if (traceId != null) 'traceId': traceId,
        if (spanId != null) 'spanId': spanId,
      };
}
