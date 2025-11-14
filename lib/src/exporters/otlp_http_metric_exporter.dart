import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../sdk/metrics/metric_data.dart';
import '../sdk/resource/resource.dart';
import '../proto/opentelemetry/proto/collector/metrics/v1/metrics_service.pb.dart';
import 'protobuf_converter.dart';
import 'http2_stub.dart'
    if (dart.library.io) 'http2_io.dart'
    if (dart.library.html) 'http2_web.dart';

/// OTLP HTTP metric exporter that sends metrics to an OTLP endpoint.
class OtlpHttpMetricExporter {

  OtlpHttpMetricExporter({
    required String endpoint,
    Map<String, String>? headers,
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
    bool useHttp2 = false,
  })  : endpoint = Uri.parse(endpoint.endsWith('/v1/metrics')
            ? endpoint
            : '$endpoint/v1/metrics',),
        headers = {
          'Content-Type': useHttp2 ? 'application/x-protobuf' : 'application/json',
          ...?headers,
        },
        _httpClient = useHttp2 ? null : (client ?? http.Client()),
        _useHttp2 = useHttp2;

  /// Creates an exporter configured for .NET Aspire Dashboard.
  /// Aspire Dashboard requires HTTP/2.
  factory OtlpHttpMetricExporter.aspire({
    String host = 'localhost',
    int port = 18889,
    Map<String, String>? headers,
  }) {
    return OtlpHttpMetricExporter(
      endpoint: 'http://$host:$port/v1/metrics',
      headers: headers,
      useHttp2: true,
    );
  }
  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final http.Client? _httpClient;
  final bool _useHttp2;

  Future<void> export(
    List<MetricData> metrics,
    Resource resource,
    InstrumentationScope scope,
  ) async {
    if (metrics.isEmpty) return;

    final List<int> body;
    if (_useHttp2) {
      // Use protobuf for HTTP/2
      final resourceMetrics =
          ProtobufConverter.metricsToProto(metrics, resource, scope);
      final request = ExportMetricsServiceRequest(
        resourceMetrics: resourceMetrics,
      );
      body = request.writeToBuffer();
    } else {
      // Use JSON for HTTP/1.1
      final jsonBody = jsonEncode({
        'resourceMetrics': [
          {
            'resource': resource.toJson(),
            'scopeMetrics': [
              {
                'scope': scope.toJson(),
                'metrics': metrics.map((m) => m.toJson()).toList(),
              }
            ],
          }
        ],
      });
      body = utf8.encode(jsonBody);
    }

    try {
      if (_useHttp2) {
        await _exportViaHttp2(body);
      } else {
        await _exportViaHttp1(body);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error exporting metrics to OTLP endpoint: $e');
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
        'Failed to export metrics: ${response.statusCode} ${response.body}',
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
          'Failed to export metrics: ${response.statusCode} $responseBody',
        );
      }
    } finally {
      await transport.finish();
    }
  }

  Future<void> shutdown() async {
    _httpClient?.close();
  }
}
