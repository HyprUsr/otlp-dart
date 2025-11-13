import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../proto/opentelemetry/proto/collector/trace/v1/trace_service.pb.dart';
import '../sdk/trace/span_exporter.dart';
import '../sdk/trace/recording_span.dart';
import 'protobuf_converter.dart';
import 'http2_stub.dart'
    if (dart.library.io) 'http2_io.dart'
    if (dart.library.html) 'http2_web.dart';

/// OTLP HTTP trace exporter that sends traces to an OTLP endpoint.
class OtlpHttpTraceExporter implements SpanExporter {
  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final http.Client? _httpClient;
  final bool _useHttp2;

  OtlpHttpTraceExporter({
    required String endpoint,
    Map<String, String>? headers,
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
    bool useHttp2 = false,
  })  : endpoint = Uri.parse(endpoint.endsWith('/v1/traces')
            ? endpoint
            : '$endpoint/v1/traces'),
        headers = {
          'Content-Type': useHttp2 ? 'application/x-protobuf' : 'application/json',
          ...?headers,
        },
        _httpClient = useHttp2 ? null : (client ?? http.Client()),
        _useHttp2 = useHttp2;

  /// Creates an exporter configured for .NET Aspire Dashboard.
  /// Aspire Dashboard requires HTTP/2.
  factory OtlpHttpTraceExporter.aspire({
    String host = 'localhost',
    int port = 18889,
    Map<String, String>? headers,
  }) {
    return OtlpHttpTraceExporter(
      endpoint: 'http://$host:$port/v1/traces',
      headers: headers,
      useHttp2: true,
    );
  }

  @override
  Future<void> export(List<RecordingSpan> spans) async {
    if (spans.isEmpty) return;

    final List<int> body;
    if (_useHttp2) {
      // Use protobuf for HTTP/2
      final request = ExportTraceServiceRequest(
        resourceSpans: ProtobufConverter.spansToProto(spans),
      );
      body = request.writeToBuffer();
    } else {
      // Use JSON for HTTP/1.1
      final resourceSpansMap = <String, Map<String, List<RecordingSpan>>>{};

      for (final span in spans) {
        final resourceKey = _resourceKey(span);
        final scopeKey = _scopeKey(span);

        resourceSpansMap.putIfAbsent(resourceKey, () => {});
        resourceSpansMap[resourceKey]!.putIfAbsent(scopeKey, () => []);
        resourceSpansMap[resourceKey]![scopeKey]!.add(span);
      }

      final resourceSpans = <Map<String, dynamic>>[];

      for (final resourceEntry in resourceSpansMap.entries) {
        final firstSpan =
            resourceSpansMap[resourceEntry.key]!.values.first.first;
        final scopeSpans = <Map<String, dynamic>>[];

        for (final scopeEntry
            in resourceSpansMap[resourceEntry.key]!.entries) {
          final scopeSpan = scopeEntry.value.first;
          scopeSpans.add({
            'scope': scopeSpan.scope.toJson(),
            'spans': scopeEntry.value.map((s) => s.toJson()).toList(),
          });
        }

        resourceSpans.add({
          'resource': firstSpan.resource.toJson(),
          'scopeSpans': scopeSpans,
        });
      }

      body = utf8.encode(
        jsonEncode({
          'resourceSpans': resourceSpans,
        }),
      );
    }

    try {
      if (_useHttp2) {
        await _exportViaHttp2(body);
      } else {
        await _exportViaHttp1(body);
      }
    } catch (e) {
      print('Error exporting traces to OTLP endpoint: $e');
      rethrow;
    }
  }

  Future<void> _exportViaHttp1(List<int> body) async {
    final response = await _httpClient!
        .post(
          endpoint,
          headers: headers,
          body: body,
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to export traces: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> _exportViaHttp2(List<int> body) async {
    final transport = await createHttp2Transport(endpoint.host, endpoint.port);

    try {
      final response = await transport.request(
        method: 'POST',
        path: endpoint.path,
        scheme: endpoint.scheme,
        authority: '${endpoint.host}:${endpoint.port}',
        headers: headers,
        body: Uint8List.fromList(body),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final responseBody = utf8.decode(response.body);
        throw Exception(
          'Failed to export traces: ${response.statusCode} $responseBody',
        );
      }
    } finally {
      await transport.finish();
    }
  }

  @override
  Future<void> forceFlush() async {
    // HTTP exporter doesn't buffer, nothing to flush
  }

  @override
  Future<void> shutdown() async {
    _httpClient?.close();
  }

  String _resourceKey(RecordingSpan span) {
    return span.resource.attributes
        .map((a) => '${a.key}=${a.value}')
        .join(',');
  }

  String _scopeKey(RecordingSpan span) {
    return '${span.scope.name}:${span.scope.version ?? ''}';
  }
}
