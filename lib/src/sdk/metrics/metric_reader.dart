import 'dart:async';
import '../../sdk/resource/resource.dart';
import '../metrics/metric_data.dart';
import '../../exporters/otlp_http_metric_exporter.dart';

/// MetricReader is responsible for collecting metrics and exporting them.
abstract class MetricReader {
  Future<void> forceFlush();
  Future<void> shutdown();
  void registerMetric(String key, MetricData Function() metricProducer);
  List<MetricData> collectMetrics();
}

/// Periodic metric reader that exports metrics on a schedule.
class PeriodicMetricReader implements MetricReader {
  final OtlpHttpMetricExporter exporter;
  final Resource resource;
  final InstrumentationScope scope;
  final Duration interval;
  final Map<String, MetricData Function()> _metricProducers = {};
  Timer? _timer;
  bool _shutdown = false;

  PeriodicMetricReader({
    required this.exporter,
    required this.resource,
    required this.scope,
    this.interval = const Duration(seconds: 60),
  }) {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(interval, (_) {
      if (!_shutdown) {
        _export();
      }
    });
  }

  @override
  void registerMetric(String key, MetricData Function() metricProducer) {
    _metricProducers[key] = metricProducer;
  }

  @override
  List<MetricData> collectMetrics() {
    // Collect all metrics - even those with no current data points
    // This ensures metric streams remain consistent for DELTA temporality
    return _metricProducers.values.map((producer) => producer()).toList();
  }

  Future<void> _export() async {
    final metrics = collectMetrics();
    if (metrics.isEmpty) return;

    try {
      await exporter.export(metrics, resource, scope);
    } catch (e) {
      print('Error exporting metrics: $e');
    }
  }

  @override
  Future<void> forceFlush() async {
    await _export();
  }

  @override
  Future<void> shutdown() async {
    if (_shutdown) return;
    _shutdown = true;
    _timer?.cancel();
    await _export();
    await exporter.shutdown();
  }
}
