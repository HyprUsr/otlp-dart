import 'dart:convert';
import 'package:http/http.dart' as http;
import '../sdk/logs/log_exporter.dart';
import '../api/logs/log_record.dart';

/// OTLP HTTP log exporter that sends logs to an OTLP endpoint.
class OtlpHttpLogExporter implements LogRecordExporter {
  final Uri endpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final http.Client _client;

  OtlpHttpLogExporter({
    required String endpoint,
    Map<String, String>? headers,
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
  })  : endpoint = Uri.parse(endpoint.endsWith('/v1/logs')
            ? endpoint
            : '$endpoint/v1/logs'),
        headers = {
          'Content-Type': 'application/json',
          ...?headers,
        },
        _client = client ?? http.Client();

  /// Creates an exporter configured for .NET Aspire Dashboard.
  factory OtlpHttpLogExporter.aspire({
    String host = 'localhost',
    int port = 18889,
    Map<String, String>? headers,
  }) {
    return OtlpHttpLogExporter(
      endpoint: 'http://$host:$port/v1/logs',
      headers: headers,
    );
  }

  @override
  Future<void> export(List<LogRecord> logRecords) async {
    if (logRecords.isEmpty) return;

    // Group log records by resource and scope
    final resourceLogsMap = <String, Map<String, List<LogRecord>>>{};

    for (final logRecord in logRecords) {
      final resourceKey = _resourceKey(logRecord);
      final scopeKey = _scopeKey(logRecord);

      resourceLogsMap.putIfAbsent(resourceKey, () => {});
      resourceLogsMap[resourceKey]!.putIfAbsent(scopeKey, () => []);
      resourceLogsMap[resourceKey]![scopeKey]!.add(logRecord);
    }

    // Build OTLP request
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

    final body = jsonEncode({
      'resourceLogs': resourceLogs,
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
          'Failed to export logs: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print('Error exporting logs to OTLP endpoint: $e');
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

  String _resourceKey(LogRecord logRecord) {
    return logRecord.resource.attributes
        .map((a) => '${a.key}=${a.value}')
        .join(',');
  }

  String _scopeKey(LogRecord logRecord) {
    return '${logRecord.scope.name}:${logRecord.scope.version ?? ''}';
  }
}
