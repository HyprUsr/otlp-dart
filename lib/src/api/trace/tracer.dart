import '../../sdk/common/attribute.dart';
import 'span.dart';
import 'span_kind.dart';

/// Tracer is the interface for creating spans.
abstract class Tracer {
  /// Starts a new span.
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Span? parent,
    Map<String, AttributeValue>? attributes,
    List<SpanLink>? links,
    DateTime? startTime,
  });

  /// Starts a new span and executes a function within its context.
  /// The span is automatically ended when the function completes.
  T withSpan<T>(
    String name,
    T Function(Span span) fn, {
    SpanKind kind = SpanKind.internal,
    Span? parent,
    Map<String, AttributeValue>? attributes,
    List<SpanLink>? links,
  });

  /// Starts a new span and executes an async function within its context.
  /// The span is automatically ended when the future completes.
  Future<T> withSpanAsync<T>(
    String name,
    Future<T> Function(Span span) fn, {
    SpanKind kind = SpanKind.internal,
    Span? parent,
    Map<String, AttributeValue>? attributes,
    List<SpanLink>? links,
  });
}
