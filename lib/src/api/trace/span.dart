import '../../sdk/common/attribute.dart';
import 'span_status.dart';

/// Span represents a single operation within a trace.
abstract class Span {
  /// Sets an attribute on the span.
  void setAttribute(String key, AttributeValue value);

  /// Sets multiple attributes on the span.
  void setAttributes(Map<String, AttributeValue> attributes);

  /// Adds an event to the span.
  void addEvent(String name, {Map<String, AttributeValue>? attributes});

  /// Sets the status of the span.
  void setStatus(SpanStatus status);

  /// Records an exception on the span.
  void recordException(
    Object exception, {
    StackTrace? stackTrace,
    Map<String, AttributeValue>? attributes,
  });

  /// Ends the span.
  void end({DateTime? endTime});

  /// Returns the span context.
  SpanContext get context;

  /// Returns whether the span is recording.
  bool get isRecording;
}

/// SpanContext contains the identifying information of a span.
class SpanContext {
  final String traceId;
  final String spanId;
  final int traceFlags;
  final String? traceState;

  SpanContext({
    required this.traceId,
    required this.spanId,
    this.traceFlags = 1, // sampled
    this.traceState,
  });

  bool get isValid => traceId.isNotEmpty && spanId.isNotEmpty;
  bool get isSampled => (traceFlags & 1) != 0;

  Map<String, dynamic> toJson() => {
        'traceId': traceId,
        'spanId': spanId,
        if (traceState != null) 'traceState': traceState,
      };
}

/// SpanEvent represents an event that occurred during a span.
class SpanEvent {
  final String name;
  final int timeUnixNano;
  final List<Attribute> attributes;
  final int droppedAttributesCount;

  SpanEvent({
    required this.name,
    required this.timeUnixNano,
    List<Attribute>? attributes,
    this.droppedAttributesCount = 0,
  }) : attributes = attributes ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'timeUnixNano': timeUnixNano.toString(),
        if (attributes.isNotEmpty)
          'attributes': attributes.map((a) => a.toJson()).toList(),
        if (droppedAttributesCount > 0)
          'droppedAttributesCount': droppedAttributesCount,
      };
}

/// SpanLink represents a link to another span.
class SpanLink {
  final SpanContext context;
  final List<Attribute> attributes;
  final int droppedAttributesCount;

  SpanLink({
    required this.context,
    List<Attribute>? attributes,
    this.droppedAttributesCount = 0,
  }) : attributes = attributes ?? [];

  Map<String, dynamic> toJson() => {
        'traceId': context.traceId,
        'spanId': context.spanId,
        if (context.traceState != null) 'traceState': context.traceState,
        if (attributes.isNotEmpty)
          'attributes': attributes.map((a) => a.toJson()).toList(),
        if (droppedAttributesCount > 0)
          'droppedAttributesCount': droppedAttributesCount,
      };
}
