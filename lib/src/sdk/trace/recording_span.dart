import '../../api/trace/span.dart';
import '../../api/trace/span_kind.dart';
import '../../api/trace/span_status.dart';
import '../../sdk/common/attribute.dart';
import '../resource/resource.dart';
import 'span_processor.dart';

/// RecordingSpan is the SDK implementation of Span.
class RecordingSpan implements Span {
  final String name;
  final SpanContext _context;
  final SpanKind kind;
  final String? parentSpanId;
  final InstrumentationScope scope;
  final Resource resource;
  final SpanProcessor processor;

  final int startTimeUnixNano;
  int? _endTimeUnixNano;

  final List<Attribute> _attributes = [];
  final List<SpanEvent> _events = [];
  final List<SpanLink> _links = [];
  SpanStatus _status = const SpanStatus.unset();

  bool _ended = false;

  RecordingSpan({
    required this.name,
    required SpanContext context,
    required this.kind,
    required this.scope,
    required this.resource,
    required this.processor,
    this.parentSpanId,
    DateTime? startTime,
    List<SpanLink>? links,
  })  : _context = context,
        startTimeUnixNano = _dateTimeToNanos(startTime ?? DateTime.now()) {
    if (links != null) {
      _links.addAll(links);
    }
  }

  @override
  SpanContext get context => _context;

  @override
  bool get isRecording => !_ended;

  /// Getters for internal state (used by exporters)
  int? get endTimeUnixNano => _endTimeUnixNano;
  List<Attribute> get attributes => _attributes;
  List<SpanEvent> get events => _events;
  List<SpanLink> get links => _links;
  SpanStatus get status => _status;

  @override
  void setAttribute(String key, AttributeValue value) {
    if (!_ended) {
      _attributes.add(Attribute(key, value));
    }
  }

  @override
  void setAttributes(Map<String, AttributeValue> attributes) {
    if (!_ended) {
      for (final entry in attributes.entries) {
        _attributes.add(Attribute(entry.key, entry.value));
      }
    }
  }

  @override
  void addEvent(String name, {Map<String, AttributeValue>? attributes}) {
    if (!_ended) {
      final attrs = attributes != null
          ? attributes.entries
              .map((e) => Attribute(e.key, e.value))
              .toList()
          : <Attribute>[];

      _events.add(SpanEvent(
        name: name,
        timeUnixNano: _dateTimeToNanos(DateTime.now()),
        attributes: attrs,
      ));
    }
  }

  @override
  void setStatus(SpanStatus status) {
    if (!_ended) {
      _status = status;
    }
  }

  @override
  void recordException(
    Object exception, {
    StackTrace? stackTrace,
    Map<String, AttributeValue>? attributes,
  }) {
    if (!_ended) {
      final attrs = <String, AttributeValue>{
        'exception.type': AttributeValue.string(exception.runtimeType.toString()),
        'exception.message': AttributeValue.string(exception.toString()),
      };

      if (stackTrace != null) {
        attrs['exception.stacktrace'] = AttributeValue.string(stackTrace.toString());
      }

      if (attributes != null) {
        attrs.addAll(attributes);
      }

      addEvent('exception', attributes: attrs);
      setStatus(SpanStatus.error(exception.toString()));
    }
  }

  @override
  void end({DateTime? endTime}) {
    if (!_ended) {
      _ended = true;
      _endTimeUnixNano = _dateTimeToNanos(endTime ?? DateTime.now());
      // Notify processor after setting end timestamp
      processor.onEnd(this);
    }
  }

  /// Converts this span to OTLP JSON format.
  Map<String, dynamic> toJson() => {
        'traceId': _context.traceId,
        'spanId': _context.spanId,
        'traceState': _context.traceState ?? '',
        'parentSpanId': parentSpanId ?? '',
        'name': name,
        'kind': kind.toInt(),
        'startTimeUnixNano': startTimeUnixNano.toString(),
        'endTimeUnixNano': (_endTimeUnixNano ?? startTimeUnixNano).toString(),
        'attributes': _attributes.map((a) => a.toJson()).toList(),
        'droppedAttributesCount': 0,
        'events': _events.map((e) => e.toJson()).toList(),
        'droppedEventsCount': 0,
        'links': _links.map((l) => l.toJson()).toList(),
        'droppedLinksCount': 0,
        'status': _status.toJson(),
      };

  static int _dateTimeToNanos(DateTime dateTime) {
    return dateTime.microsecondsSinceEpoch * 1000;
  }
}
