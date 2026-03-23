/// OpenTelemetry Protocol (OTLP) client library for Dart.
///
/// Export traces, metrics, and logs to OTLP-compatible backends
/// like .NET Aspire Dashboard, Jaeger, Prometheus, and more.
library otlp_dart;

export 'src/api/trace/tracer.dart';
export 'src/api/trace/tracer_provider.dart';
export 'src/api/trace/span.dart';
export 'src/api/trace/span_kind.dart';
export 'src/api/trace/span_status.dart';
export 'src/api/metrics/meter.dart';
export 'src/api/metrics/meter_provider.dart';
export 'src/api/logs/logger.dart';
export 'src/api/logs/logger_provider.dart';
export 'src/api/logs/log_record.dart';
export 'src/api/logs/severity.dart';

export 'src/sdk/resource/resource.dart';
export 'src/sdk/common/attribute.dart';
export 'src/sdk/trace/tracer_provider_impl.dart';
export 'src/sdk/trace/span_processor.dart';
export 'src/sdk/trace/span_exporter.dart';
export 'src/sdk/logs/logger_provider_impl.dart';
export 'src/sdk/logs/log_processor.dart';
export 'src/sdk/logs/log_exporter.dart';
export 'src/sdk/metrics/meter_provider_impl.dart';
export 'src/sdk/metrics/metric_reader.dart';

export 'src/exporters/otlp_http_trace_exporter.dart';
export 'src/exporters/otlp_http_metric_exporter.dart';
export 'src/exporters/otlp_http_log_exporter.dart';

export 'src/instrumentation/otlp_http_client.dart';
export 'src/instrumentation/http_semantic_conventions.dart';
