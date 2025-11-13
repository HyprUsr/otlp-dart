import 'dart:convert';
import 'package:http/http.dart' as http;
import '../sdk/trace/span_exporter.dart';
import '../sdk/trace/recording_span.dart';

/// OTLP HTTP trace exporter that sends traces to an OTLP endpoint.
class OtlpHttpTraceExporter implements SpanExporter {
  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final http.Client _client;

  OtlpHttpTraceExporter({
    required String endpoint,
    Map<String, String>? headers,
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
  })  : endpoint = Uri.parse(endpoint.endsWith('/v1/traces')
            ? endpoint
            : '$endpoint/v1/traces'),
        headers = {
          'Content-Type': 'application/json',
          ...?headers,
        },
        _client = client ?? http.Client();

  /// Creates an exporter configured for .NET Aspire Dashboard.
  factory OtlpHttpTraceExporter.aspire({
    String host = 'localhost',
    int port = 18889,
    Map<String, String>? headers,
  }) {
    return OtlpHttpTraceExporter(
      endpoint: 'http://$host:$port/v1/traces',
      headers: headers,
    );
  }

  @override
  Future<void> export(List<RecordingSpan> spans) async {
    if (spans.isEmpty) return;

    // Group spans by resource and scope
    final resourceSpansMap = <String, Map<String, List<RecordingSpan>>>{};

    for (final span in spans) {
      final resourceKey = _resourceKey(span);
      final scopeKey = _scopeKey(span);

      resourceSpansMap.putIfAbsent(resourceKey, () => {});
      resourceSpansMap[resourceKey]!.putIfAbsent(scopeKey, () => []);
      resourceSpansMap[resourceKey]![scopeKey]!.add(span);
    }

    // Build OTLP request
    final resourceSpans = <Map<String, dynamic>>[];

    for (final resourceEntry in resourceSpansMap.entries) {
      final firstSpan = resourceSpansMap[resourceEntry.key]!.values.first.first;
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

    final body = jsonEncode({
      'resourceSpans': resourceSpans,
    });

    try {
      final response = await _client
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
    } catch (e) {
      print('Error exporting traces to OTLP endpoint: $e');
      rethrow;
    }
  }

  @override
  Future<void> forceFlush() async {
    // HTTP exporter doesn't buffer, nothing to flush
  }

  @override
  Future<void> shutdown() async {
    _client.close();
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
