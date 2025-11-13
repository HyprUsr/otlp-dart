import 'dart:convert';
import 'package:http/http.dart' as http;
import '../sdk/metrics/metric_data.dart';
import '../sdk/resource/resource.dart';

/// OTLP HTTP metric exporter that sends metrics to an OTLP endpoint.
class OtlpHttpMetricExporter {
  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final http.Client _client;

  OtlpHttpMetricExporter({
    required String endpoint,
    Map<String, String>? headers,
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
  })  : endpoint = Uri.parse(endpoint.endsWith('/v1/metrics')
            ? endpoint
            : '$endpoint/v1/metrics'),
        headers = {
          'Content-Type': 'application/json',
          ...?headers,
        },
        _client = client ?? http.Client();

  /// Creates an exporter configured for .NET Aspire Dashboard.
  factory OtlpHttpMetricExporter.aspire({
    String host = 'localhost',
    int port = 18889,
    Map<String, String>? headers,
  }) {
    return OtlpHttpMetricExporter(
      endpoint: 'http://$host:$port/v1/metrics',
      headers: headers,
    );
  }

  Future<void> export(
    List<MetricData> metrics,
    Resource resource,
    InstrumentationScope scope,
  ) async {
    if (metrics.isEmpty) return;

    final body = jsonEncode({
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
          'Failed to export metrics: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print('Error exporting metrics to OTLP endpoint: $e');
      rethrow;
    }
  }

  Future<void> shutdown() async {
    _client.close();
  }
}
