/// StatusCode represents the status of a Span.
enum StatusCode {
  /// The default status.
  unset,

  /// The operation completed successfully.
  ok,

  /// The operation contains an error.
  error,
}

extension StatusCodeExtension on StatusCode {
  int toInt() {
    switch (this) {
      case StatusCode.unset:
        return 0;
      case StatusCode.ok:
        return 1;
      case StatusCode.error:
        return 2;
    }
  }
}

/// Status represents the status of a finished Span.
class SpanStatus {
  final StatusCode code;
  final String? message;

  const SpanStatus({
    required this.code,
    this.message,
  });

  const SpanStatus.unset() : this(code: StatusCode.unset);
  const SpanStatus.ok() : this(code: StatusCode.ok);
  const SpanStatus.error([String? message])
      : this(code: StatusCode.error, message: message);

  Map<String, dynamic> toJson() => {
        'code': code.toInt(),
        if (message != null && message!.isNotEmpty) 'message': message,
      };
}
