import 'package:otlp_dart/otlp_dart.dart';
import 'package:otlp_dart/src/sdk/metrics/metric_data.dart';

void main() async {
  final resource = Resource.create(serviceName: 'test');
  final exporter = OtlpHttpMetricExporter.aspire(host: 'localhost', port: 18889);
  final reader = PeriodicMetricReader(
    exporter: exporter,
    resource: resource,
    scope: InstrumentationScope(name: 'test', version: '1.0.0'),
  );
  final meterProvider = MeterProviderImpl(resource: resource, reader: reader);
  final meter = meterProvider.getMeter('test');

  final appStartTime = meter.createHistogram('app.start.duration', unit: 'ms');

  // Record a value
  print('Recording value...');
  appStartTime.record(1234.5, attributes: {
    'app.version': AttributeValue.string('1.0.0'),
    'environment': AttributeValue.string('development'),
  });

  // Collect and print
  print('\nCollecting metrics...');
  final metrics = reader.collectMetrics();
  print('Collected metrics: ${metrics.length}');
  for (final m in metrics) {
    print('\nMetric: ${m.name}');
    if (m is HistogramData) {
      print('  Data points: ${m.dataPoints.length}');
      for (final dp in m.dataPoints) {
        print('    Count: ${dp.count}, Sum: ${dp.sum}, Min: ${dp.min}, Max: ${dp.max}');
        print('    Attributes: ${dp.attributes.length}');
        for (final attr in dp.attributes) {
          print('      ${attr.key} = ${attr.value.stringValue ?? attr.value.intValue ?? attr.value.doubleValue}');
        }
        print('    Buckets: ${dp.bucketCounts}');
        print('    Bounds: ${dp.explicitBounds}');
      }
    }
  }

  print('\nFlushing...');
  await meterProvider.forceFlush();
  print('Done!');

  await meterProvider.shutdown();
}
