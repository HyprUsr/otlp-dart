import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../api/logs/log_record.dart';
import '../proto/opentelemetry/proto/collector/logs/v1/logs_service.pb.dart';
import '../sdk/logs/log_exporter.dart';
import 'protobuf_converter.dart';
import 'http2_stub.dart'
    if (dart.library.io) 'http2_io.dart'
    if (dart.library.html) 'http2_web.dart';

/// OTLP HTTP log exporter that sends logs to an OTLP endpoint.
class OtlpHttpLogExporter implements LogRecordExporter {
  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final http.Client? _httpClient;
  final bool _useHttp2;

  OtlpHttpLogExporter({
    required String endpoint,
    Map<String, String>? headers,
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
    bool useHttp2 = false,
  })  : endpoint = Uri.parse(endpoint.endsWith('/v1/logs')
            ? endpoint
            : '$endpoint/v1/logs'),
        headers = {
          'Content-Type': useHttp2 ? 'application/x-protobuf' : 'application/json',
          ...?headers,
        },
        _httpClient = useHttp2 ? null : (client ?? http.Client()),
        _useHttp2 = useHttp2;

  /// Creates an exporter configured for .NET Aspire Dashboard.
  /// Aspire Dashboard requires HTTP/2.
  factory OtlpHttpLogExporter.aspire({
    String host = 'localhost',
    int port = 18889,
    Map<String, String>? headers,
  }) {
    return OtlpHttpLogExporter(
      endpoint: 'http://$host:$port/v1/logs',
      headers: headers,
      useHttp2: true,
    );
  }

  @override
  Future<void> export(List<LogRecord> logRecords) async {
    if (logRecords.isEmpty) return;

    final List<int> body;
    if (_useHttp2) {
      // Use protobuf for HTTP/2
      final request = ExportLogsServiceRequest(
        resourceLogs: ProtobufConverter.logsToProto(logRecords),
      );
      body = request.writeToBuffer();
    } else {
      // Use JSON for HTTP/1.1
      final resourceLogsMap = <String, Map<String, List<LogRecord>>>{};

      for (final logRecord in logRecords) {
        final resourceKey = _resourceKey(logRecord);
        final scopeKey = _scopeKey(logRecord);

        resourceLogsMap.putIfAbsent(resourceKey, () => {});
        resourceLogsMap[resourceKey]!.putIfAbsent(scopeKey, () => []);
        resourceLogsMap[resourceKey]![scopeKey]!.add(logRecord);
      }

      final resourceLogs = <Map<String, dynamic>>[];

      for (final resourceEntry in resourceLogsMap.entries) {
        final firstLog = resourceLogsMap[resourceEntry.key]!.values.first.first;
        final scopeLogs = <Map<String, dynamic>>[];

        for (final scopeEntry in resourceLogsMap[resourceEntry.key]!.entries) {
          final scopeLog = scopeEntry.value.first;
          scopeLogs.add({
            'scope': scopeLog.scope.toJson(),
            'logRecords': scopeEntry.value.map((l) => l.toJson()).toList(),
          });
        }

        resourceLogs.add({
          'resource': firstLog.resource.toJson(),
          'scopeLogs': scopeLogs,
        });
      }

      body = utf8.encode(
        jsonEncode({
          'resourceLogs': resourceLogs,
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
      print('Error exporting logs to OTLP endpoint: $e');
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
        'Failed to export logs: ${response.statusCode} ${response.body}',
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
          'Failed to export logs: ${response.statusCode} $responseBody',
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

  String _resourceKey(LogRecord logRecord) {
    return logRecord.resource.attributes
        .map((a) => '${a.key}=${a.value}')
        .join(',');
  }

  String _scopeKey(LogRecord logRecord) {
    return '${logRecord.scope.name}:${logRecord.scope.version ?? ''}';
  }
}
