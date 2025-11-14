import 'package:fixnum/fixnum.dart';
import '../api/logs/log_record.dart' as api_log;
import '../api/logs/severity.dart';
import '../api/trace/span.dart';
import '../api/trace/span_kind.dart';
import '../api/trace/span_status.dart';
import '../sdk/common/attribute.dart';
import '../sdk/resource/resource.dart';
import '../sdk/trace/recording_span.dart';
import '../sdk/metrics/metric_data.dart';
import '../proto/opentelemetry/proto/common/v1/common.pb.dart' as common_pb;
import '../proto/opentelemetry/proto/resource/v1/resource.pb.dart'
    as resource_pb;
import '../proto/opentelemetry/proto/trace/v1/trace.pb.dart' as trace_pb;
import '../proto/opentelemetry/proto/logs/v1/logs.pb.dart' as logs_pb;
import '../proto/opentelemetry/proto/metrics/v1/metrics.pb.dart'
    as metrics_pb;

/// Converts internal SDK types to protobuf types.
class ProtobufConverter {
  /// Converts a list of RecordingSpans to protobuf ResourceSpans.
  static List<trace_pb.ResourceSpans> spansToProto(
    List<RecordingSpan> spans,
  ) {
    // Group spans by resource and scope
    final resourceSpansMap = <String, Map<String, List<RecordingSpan>>>{};

    for (final span in spans) {
      final resourceKey = _resourceKey(span.resource);
      final scopeKey = _scopeKey(span.scope);

      resourceSpansMap.putIfAbsent(resourceKey, () => {});
      resourceSpansMap[resourceKey]!.putIfAbsent(scopeKey, () => []);
      resourceSpansMap[resourceKey]![scopeKey]!.add(span);
    }

    final resourceSpans = <trace_pb.ResourceSpans>[];

    for (final resourceEntry in resourceSpansMap.entries) {
      final firstSpan = resourceSpansMap[resourceEntry.key]!.values.first.first;
      final scopeSpans = <trace_pb.ScopeSpans>[];

      for (final scopeEntry in resourceSpansMap[resourceEntry.key]!.entries) {
        final scopeSpan = scopeEntry.value.first;
        scopeSpans.add(
          trace_pb.ScopeSpans(
            scope: _scopeToProto(scopeSpan.scope),
            spans: scopeEntry.value.map(_spanToProto).toList(),
          ),
        );
      }

      resourceSpans.add(
        trace_pb.ResourceSpans(
          resource: _resourceToProto(firstSpan.resource),
          scopeSpans: scopeSpans,
        ),
      );
    }

    return resourceSpans;
  }

  /// Converts a list of LogRecords to protobuf ResourceLogs.
  static List<logs_pb.ResourceLogs> logsToProto(
    List<api_log.LogRecord> logRecords,
  ) {
    // Group log records by resource and scope
    final resourceLogsMap = <String, Map<String, List<api_log.LogRecord>>>{};

    for (final logRecord in logRecords) {
      final resourceKey = _resourceKey(logRecord.resource);
      final scopeKey = _scopeKey(logRecord.scope);

      resourceLogsMap.putIfAbsent(resourceKey, () => {});
      resourceLogsMap[resourceKey]!.putIfAbsent(scopeKey, () => []);
      resourceLogsMap[resourceKey]![scopeKey]!.add(logRecord);
    }

    final resourceLogs = <logs_pb.ResourceLogs>[];

    for (final resourceEntry in resourceLogsMap.entries) {
      final firstLog = resourceLogsMap[resourceEntry.key]!.values.first.first;
      final scopeLogs = <logs_pb.ScopeLogs>[];

      for (final scopeEntry in resourceLogsMap[resourceEntry.key]!.entries) {
        final scopeLog = scopeEntry.value.first;
        scopeLogs.add(
          logs_pb.ScopeLogs(
            scope: _scopeToProto(scopeLog.scope),
            logRecords: scopeEntry.value.map(_logRecordToProto).toList(),
          ),
        );
      }

      resourceLogs.add(
        logs_pb.ResourceLogs(
          resource: _resourceToProto(firstLog.resource),
          scopeLogs: scopeLogs,
        ),
      );
    }

    return resourceLogs;
  }

  static trace_pb.Span _spanToProto(RecordingSpan span) {
    return trace_pb.Span(
      traceId: _hexToBytes(span.context.traceId),
      spanId: _hexToBytes(span.context.spanId),
      traceState: span.context.traceState ?? '',
      parentSpanId:
          span.parentSpanId != null ? _hexToBytes(span.parentSpanId!) : [],
      name: span.name,
      kind: _spanKindToProto(span.kind),
      startTimeUnixNano: Int64(span.startTimeUnixNano),
      endTimeUnixNano: Int64(span.endTimeUnixNano ?? span.startTimeUnixNano),
      attributes: span.attributes.map(_attributeToProto).toList(),
      droppedAttributesCount: 0,
      events: span.events.map(_eventToProto).toList(),
      droppedEventsCount: 0,
      links: span.links.map(_linkToProto).toList(),
      droppedLinksCount: 0,
      status: _statusToProto(span.status),
    );
  }

  static logs_pb.LogRecord _logRecordToProto(api_log.LogRecord logRecord) {
    final severityNumber = _severityToProto(logRecord.severity);

    return logs_pb.LogRecord(
      timeUnixNano: Int64(logRecord.timeUnixNano),
      observedTimeUnixNano: Int64(logRecord.observedTimeUnixNano),
      severityNumber: severityNumber,
      severityText: logRecord.severity.text,
      body: common_pb.AnyValue(
        stringValue: logRecord.body,
      ),
      attributes: logRecord.attributes.map(_attributeToProto).toList(),
      droppedAttributesCount: 0,
      traceId:
          logRecord.traceId != null ? _hexToBytes(logRecord.traceId!) : [],
      spanId: logRecord.spanId != null ? _hexToBytes(logRecord.spanId!) : [],
    );
  }

  static resource_pb.Resource _resourceToProto(Resource resource) {
    return resource_pb.Resource(
      attributes: resource.attributes.map(_attributeToProto).toList(),
    );
  }

  static common_pb.InstrumentationScope _scopeToProto(
    InstrumentationScope scope,
  ) {
    return common_pb.InstrumentationScope(
      name: scope.name,
      version: scope.version ?? '',
    );
  }

  static common_pb.KeyValue _attributeToProto(Attribute attribute) {
    return common_pb.KeyValue(
      key: attribute.key,
      value: _attributeValueToProto(attribute.value),
    );
  }

  static common_pb.AnyValue _attributeValueToProto(AttributeValue value) {
    if (value.stringValue != null) {
      return common_pb.AnyValue(stringValue: value.stringValue!);
    } else if (value.intValue != null) {
      return common_pb.AnyValue(intValue: Int64(value.intValue!));
    } else if (value.doubleValue != null) {
      return common_pb.AnyValue(doubleValue: value.doubleValue!);
    } else if (value.boolValue != null) {
      return common_pb.AnyValue(boolValue: value.boolValue!);
    } else if (value.arrayValue != null) {
      return common_pb.AnyValue(
        arrayValue: common_pb.ArrayValue(
          values: value.arrayValue!.map(_attributeValueToProto).toList(),
        ),
      );
    } else if (value.kvlistValue != null) {
      return common_pb.AnyValue(
        kvlistValue: common_pb.KeyValueList(
          values: value.kvlistValue!.entries
              .map(
                (e) => common_pb.KeyValue(
                  key: e.key,
                  value: _attributeValueToProto(e.value),
                ),
              )
              .toList(),
        ),
      );
    }
    return common_pb.AnyValue();
  }

  static trace_pb.Span_Event _eventToProto(SpanEvent event) {
    return trace_pb.Span_Event(
      timeUnixNano: Int64(event.timeUnixNano),
      name: event.name,
      attributes: event.attributes.map(_attributeToProto).toList(),
      droppedAttributesCount: 0,
    );
  }

  static trace_pb.Span_Link _linkToProto(SpanLink link) {
    return trace_pb.Span_Link(
      traceId: _hexToBytes(link.context.traceId),
      spanId: _hexToBytes(link.context.spanId),
      traceState: link.context.traceState ?? '',
      attributes: link.attributes.map(_attributeToProto).toList(),
      droppedAttributesCount: 0,
    );
  }

  static trace_pb.Status _statusToProto(SpanStatus status) {
    return trace_pb.Status(
      code: _statusCodeToProto(status.code),
      message: status.message ?? '',
    );
  }

  static trace_pb.Status_StatusCode _statusCodeToProto(StatusCode code) {
    switch (code) {
      case StatusCode.unset:
        return trace_pb.Status_StatusCode.STATUS_CODE_UNSET;
      case StatusCode.ok:
        return trace_pb.Status_StatusCode.STATUS_CODE_OK;
      case StatusCode.error:
        return trace_pb.Status_StatusCode.STATUS_CODE_ERROR;
    }
  }

  static trace_pb.Span_SpanKind _spanKindToProto(SpanKind kind) {
    switch (kind) {
      case SpanKind.internal:
        return trace_pb.Span_SpanKind.SPAN_KIND_INTERNAL;
      case SpanKind.server:
        return trace_pb.Span_SpanKind.SPAN_KIND_SERVER;
      case SpanKind.client:
        return trace_pb.Span_SpanKind.SPAN_KIND_CLIENT;
      case SpanKind.producer:
        return trace_pb.Span_SpanKind.SPAN_KIND_PRODUCER;
      case SpanKind.consumer:
        return trace_pb.Span_SpanKind.SPAN_KIND_CONSUMER;
    }
  }

  static logs_pb.SeverityNumber _severityToProto(Severity severity) {
    // Map Dart severity enum value directly to protobuf severity number
    return logs_pb.SeverityNumber.valueOf(severity.value) ??
        logs_pb.SeverityNumber.SEVERITY_NUMBER_UNSPECIFIED;
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Converts a list of MetricData to protobuf ResourceMetrics.
  static List<metrics_pb.ResourceMetrics> metricsToProto(
    List<MetricData> metrics,
    Resource resource,
    InstrumentationScope scope,
  ) {
    if (metrics.isEmpty) return [];

    final scopeMetrics = metrics_pb.ScopeMetrics(
      scope: _scopeToProto(scope),
      metrics: metrics.map(_metricToProto).toList(),
    );

    return [
      metrics_pb.ResourceMetrics(
        resource: _resourceToProto(resource),
        scopeMetrics: [scopeMetrics],
      ),
    ];
  }

  static metrics_pb.Metric _metricToProto(MetricData metric) {
    if (metric is SumData) {
      return metrics_pb.Metric(
        name: metric.name,
        description: metric.description ?? '',
        unit: metric.unit ?? '',
        sum: metrics_pb.Sum(
          dataPoints: metric.dataPoints
              .map((dp) => _numberDataPointToProto(dp))
              .toList(),
          aggregationTemporality:
              metrics_pb.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA,
          isMonotonic: metric.isMonotonic,
        ),
      );
    } else if (metric is GaugeData) {
      return metrics_pb.Metric(
        name: metric.name,
        description: metric.description ?? '',
        unit: metric.unit ?? '',
        gauge: metrics_pb.Gauge(
          dataPoints: metric.dataPoints
              .map((dp) => _numberDataPointToProto(dp))
              .toList(),
        ),
      );
    } else if (metric is HistogramData) {
      return metrics_pb.Metric(
        name: metric.name,
        description: metric.description ?? '',
        unit: metric.unit ?? '',
        histogram: metrics_pb.Histogram(
          dataPoints: metric.dataPoints
              .map((dp) => _histogramDataPointToProto(dp))
              .toList(),
          aggregationTemporality:
              metrics_pb.AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA,
        ),
      );
    } else {
      throw UnimplementedError('Unknown metric type: ${metric.runtimeType}');
    }
  }

  static metrics_pb.NumberDataPoint _numberDataPointToProto(DataPoint dp) {
    return metrics_pb.NumberDataPoint(
      attributes: dp.attributes.map(_attributeToProto).toList(),
      startTimeUnixNano: Int64(dp.startTimeUnixNano),
      timeUnixNano: Int64(dp.timeUnixNano),
      asDouble: dp.value.toDouble(),
    );
  }

  static metrics_pb.HistogramDataPoint _histogramDataPointToProto(
      HistogramDataPoint dp,) {
    return metrics_pb.HistogramDataPoint(
      attributes: dp.attributes.map(_attributeToProto).toList(),
      startTimeUnixNano: Int64(dp.startTimeUnixNano),
      timeUnixNano: Int64(dp.timeUnixNano),
      count: Int64(dp.count),
      sum: dp.sum,
      bucketCounts: dp.bucketCounts.map((c) => Int64(c)).toList(),
      explicitBounds: dp.explicitBounds,
      min: dp.min,
      max: dp.max,
    );
  }

  static String _resourceKey(Resource resource) {
    final sorted = resource.attributes.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((a) => '${a.key}=${_attributeValueToString(a.value)}').join(',');
  }

  static String _scopeKey(InstrumentationScope scope) {
    return '${scope.name}:${scope.version ?? ''}';
  }

  static String _attributeValueToString(AttributeValue value) {
    if (value.stringValue != null) return 's:${value.stringValue}';
    if (value.intValue != null) return 'i:${value.intValue}';
    if (value.doubleValue != null) return 'd:${value.doubleValue}';
    if (value.boolValue != null) return 'b:${value.boolValue}';
    if (value.arrayValue != null) {
      return 'a:[${value.arrayValue!.map(_attributeValueToString).join(',')}]';
    }
    if (value.kvlistValue != null) {
      return 'kv:{${value.kvlistValue!.entries.map((e) => '${e.key}=${_attributeValueToString(e.value)}').join(',')}}';
    }
    return '';
  }
}
