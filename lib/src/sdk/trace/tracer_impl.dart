import 'dart:math';
import '../../api/trace/tracer.dart';
import '../../api/trace/span.dart';
import '../../api/trace/span_kind.dart';
import '../../sdk/common/attribute.dart';
import '../../sdk/resource/resource.dart';
import 'recording_span.dart';
import 'span_processor.dart';

/// Implementation of the Tracer interface.
class TracerImpl implements Tracer {
  final InstrumentationScope scope;
  final Resource resource;
  final SpanProcessor processor;
  final Random _random = Random();

  TracerImpl({
    required this.scope,
    required this.resource,
    required this.processor,
  });

  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Span? parent,
    Map<String, AttributeValue>? attributes,
    List<SpanLink>? links,
    DateTime? startTime,
  }) {
    final parentContext = parent?.context;
    final traceId = parentContext?.traceId ?? _generateTraceId();
    final spanId = _generateSpanId();

    final context = SpanContext(
      traceId: traceId,
      spanId: spanId,
      traceFlags: parentContext?.traceFlags ?? 1,
      traceState: parentContext?.traceState,
    );

    final span = RecordingSpan(
      name: name,
      context: context,
      kind: kind,
      scope: scope,
      resource: resource,
      parentSpanId: parentContext?.spanId,
      startTime: startTime,
      links: links,
    );

    if (attributes != null) {
      span.setAttributes(attributes);
    }

    processor.onStart(span);

    return span;
  }

  @override
  T withSpan<T>(
    String name,
    T Function(Span span) fn, {
    SpanKind kind = SpanKind.internal,
    Span? parent,
    Map<String, AttributeValue>? attributes,
    List<SpanLink>? links,
  }) {
    final span = startSpan(
      name,
      kind: kind,
      parent: parent,
      attributes: attributes,
      links: links,
    );

    try {
      final result = fn(span);
      span.end();
      return result;
    } catch (e, stackTrace) {
      span.recordException(e, stackTrace: stackTrace);
      span.end();
      rethrow;
    }
  }

  @override
  Future<T> withSpanAsync<T>(
    String name,
    Future<T> Function(Span span) fn, {
    SpanKind kind = SpanKind.internal,
    Span? parent,
    Map<String, AttributeValue>? attributes,
    List<SpanLink>? links,
  }) async {
    final span = startSpan(
      name,
      kind: kind,
      parent: parent,
      attributes: attributes,
      links: links,
    );

    try {
      final result = await fn(span);
      span.end();
      return result;
    } catch (e, stackTrace) {
      span.recordException(e, stackTrace: stackTrace);
      span.end();
      rethrow;
    }
  }

  String _generateTraceId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _generateSpanId() {
    final bytes = List<int>.generate(8, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
