import 'dart:async';
import 'package:http/http.dart' as http;
import '../api/trace/span.dart';
import '../api/trace/span_kind.dart';
import '../api/trace/span_status.dart';
import '../api/trace/tracer.dart';
import '../sdk/common/attribute.dart';
import 'http_semantic_conventions.dart';

/// An HTTP client that automatically instruments all requests with OpenTelemetry tracing.
///
/// This client wraps any `http.BaseClient` and creates spans for each request,
/// capturing request/response details, timing, and errors similar to how ASP.NET Core
/// Kestrel reports to Aspire Dashboard.
///
/// This design allows you to compose multiple HTTP client behaviors:
/// ```dart
/// // Chain multiple client wrappers together
/// final loggingClient = LoggingHttpClient();
/// final retryClient = RetryClient(loggingClient);
/// final instrumentedClient = OtlpHttpClient(tracer, inner: retryClient);
///
/// // Now you get: instrumentation + retries + logging!
/// final response = await instrumentedClient.get(Uri.parse('https://api.example.com'));
/// ```
///
/// Basic usage:
/// ```dart
/// final tracer = tracerProvider.getTracer('my-app');
/// final client = OtlpHttpClient(tracer);
///
/// try {
///   final response = await client.get(Uri.parse('https://api.example.com/users'));
///   print(response.body);
/// } finally {
///   client.close();
/// }
/// ```
class OtlpHttpClient extends http.BaseClient {
  final Tracer tracer;
  final http.BaseClient _inner;
  final bool captureHeaders;
  final bool captureRequestBody;
  final bool captureResponseBody;
  final int maxBodyCaptureSize;

  OtlpHttpClient(
    this.tracer, {
    http.BaseClient? inner,
    this.captureHeaders = true,
    this.captureRequestBody = false,
    this.captureResponseBody = false,
    this.maxBodyCaptureSize = 1024,
  }) : _inner = inner ?? (http.Client() as http.BaseClient);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method;
    final uri = request.url;
    final spanName = HttpSemanticConventions.getClientSpanName(method);

    return await tracer.withSpanAsync<http.StreamedResponse>(
      spanName,
      (span) async {
        // Set basic HTTP attributes
        _setRequestAttributes(span, request);

        final startTime = DateTime.now();

        try {
          // Send the actual request
          final response = await _inner.send(request);

          // Set response attributes
          await _setResponseAttributes(span, response, startTime);

          // Determine span status based on HTTP status code
          _setSpanStatus(span, response.statusCode);

          return response;
        } catch (e, stackTrace) {
          // Record the exception
          span.recordException(e, stackTrace: stackTrace);
          span.setStatus(SpanStatus.error(e.toString()));

          // Set error type attribute
          span.setAttribute(
            HttpSemanticConventions.errorType,
            AttributeValue.string(e.runtimeType.toString()),
          );

          rethrow;
        }
      },
      kind: SpanKind.client,
    );
  }

  void _setRequestAttributes(Span span, http.BaseRequest request) {
    final uri = request.url;

    // Required attributes
    span.setAttribute(
      HttpSemanticConventions.httpRequestMethod,
      AttributeValue.string(request.method),
    );
    span.setAttribute(
      HttpSemanticConventions.urlFull,
      AttributeValue.string(uri.toString()),
    );
    span.setAttribute(
      HttpSemanticConventions.serverAddress,
      AttributeValue.string(uri.host),
    );

    // Optional attributes
    if (uri.hasPort) {
      span.setAttribute(
        HttpSemanticConventions.serverPort,
        AttributeValue.int(uri.port),
      );
    }

    if (uri.scheme.isNotEmpty) {
      span.setAttribute(
        HttpSemanticConventions.urlScheme,
        AttributeValue.string(uri.scheme),
      );
    }

    if (uri.path.isNotEmpty) {
      span.setAttribute(
        HttpSemanticConventions.urlPath,
        AttributeValue.string(uri.path),
      );
    }

    if (uri.query.isNotEmpty) {
      span.setAttribute(
        HttpSemanticConventions.urlQuery,
        AttributeValue.string(uri.query),
      );
    }

    // Network protocol
    span.setAttribute(
      HttpSemanticConventions.networkProtocolName,
      AttributeValue.string('http'),
    );

    // Capture headers if enabled
    if (captureHeaders) {
      _captureRequestHeaders(span, request.headers);
    }

    // Capture request body size
    if (request.contentLength != null) {
      span.setAttribute(
        HttpSemanticConventions.httpRequestBodySize,
        AttributeValue.int(request.contentLength!),
      );
    }

    // Capture request body if enabled
    if (captureRequestBody && request is http.Request) {
      _captureRequestBody(span, request);
    }
  }

  Future<void> _setResponseAttributes(
    Span span,
    http.StreamedResponse response,
    DateTime startTime,
  ) async {
    // HTTP status code
    span.setAttribute(
      HttpSemanticConventions.httpResponseStatusCode,
      AttributeValue.int(response.statusCode),
    );

    // Response body size
    if (response.contentLength != null) {
      span.setAttribute(
        HttpSemanticConventions.httpResponseBodySize,
        AttributeValue.int(response.contentLength!),
      );
    }

    // Network protocol version
    if (response.reasonPhrase != null) {
      span.setAttribute(
        HttpSemanticConventions.networkProtocolVersion,
        AttributeValue.string(_getHttpVersion(response)),
      );
    }

    // Capture response headers if enabled
    if (captureHeaders) {
      _captureResponseHeaders(span, response.headers);
    }

    // Add timing event
    final duration = DateTime.now().difference(startTime);
    span.addEvent(
      'http.response.received',
      attributes: {
        'duration_ms': AttributeValue.int(duration.inMilliseconds),
      },
    );
  }

  void _setSpanStatus(Span span, int statusCode) {
    if (statusCode >= 200 && statusCode < 400) {
      span.setStatus(SpanStatus.ok());
    } else if (statusCode >= 400 && statusCode < 600) {
      span.setStatus(
        SpanStatus.error('HTTP $statusCode'),
      );
    }
  }

  void _captureRequestHeaders(Span span, Map<String, String> headers) {
    for (final entry in headers.entries) {
      final headerName = entry.key.toLowerCase();
      // Skip sensitive headers
      if (_isSensitiveHeader(headerName)) continue;

      span.setAttribute(
        '${HttpSemanticConventions.httpRequestHeader}.$headerName',
        AttributeValue.string(entry.value),
      );
    }
  }

  void _captureResponseHeaders(Span span, Map<String, String> headers) {
    for (final entry in headers.entries) {
      final headerName = entry.key.toLowerCase();
      // Skip sensitive headers
      if (_isSensitiveHeader(headerName)) continue;

      span.setAttribute(
        '${HttpSemanticConventions.httpResponseHeader}.$headerName',
        AttributeValue.string(entry.value),
      );
    }
  }

  void _captureRequestBody(Span span, http.Request request) {
    try {
      if (request.body.isNotEmpty &&
          request.body.length <= maxBodyCaptureSize) {
        span.addEvent(
          'http.request.body',
          attributes: {
            'body': AttributeValue.string(
              request.body.substring(
                0,
                request.body.length.clamp(0, maxBodyCaptureSize),
              ),
            ),
          },
        );
      }
    } catch (e) {
      // Silently ignore body capture errors
    }
  }

  String _getHttpVersion(http.StreamedResponse response) {
    // Try to extract HTTP version from response
    // Most HTTP clients don't expose this easily, so we default to 1.1
    return '1.1';
  }

  bool _isSensitiveHeader(String headerName) {
    const sensitiveHeaders = {
      'authorization',
      'cookie',
      'set-cookie',
      'x-api-key',
      'x-auth-token',
      'proxy-authorization',
    };
    return sensitiveHeaders.contains(headerName);
  }

  @override
  void close() {
    _inner.close();
  }
}
