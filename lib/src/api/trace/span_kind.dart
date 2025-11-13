/// SpanKind describes the relationship between the Span, its parents,
/// and its children in a Trace.
enum SpanKind {
  /// Default value. Indicates that the span is used internally.
  internal,

  /// Indicates that the span covers server-side handling of an RPC or other
  /// remote request.
  server,

  /// Indicates that the span covers the client-side wrapper around an RPC or
  /// other remote request.
  client,

  /// Indicates that the span describes producer sending a message to a broker.
  producer,

  /// Indicates that the span describes consumer receiving a message from a broker.
  consumer,
}

extension SpanKindExtension on SpanKind {
  int toInt() {
    switch (this) {
      case SpanKind.internal:
        return 1;
      case SpanKind.server:
        return 2;
      case SpanKind.client:
        return 3;
      case SpanKind.producer:
        return 4;
      case SpanKind.consumer:
        return 5;
    }
  }
}
