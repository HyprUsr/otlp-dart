import 'dart:async';
import 'package:otlp_dart/otlp_dart.dart';

void main() async {
  final resource = Resource.create(serviceName: 'histogram-test');
  final exporter = OtlpHttpMetricExporter.aspire(host: 'localhost', port: 18889);
  final reader = PeriodicMetricReader(
    exporter: exporter,
    resource: resource,
    scope: InstrumentationScope(name: 'test', version: '1.0.0'),
    interval: const Duration(seconds: 5), // Export every 5 seconds
  );
  final meterProvider = MeterProviderImpl(resource: resource, reader: reader);
  final meter = meterProvider.getMeter('test');

  final appStartTime = meter.createHistogram('app.start.duration',
    unit: 'ms',
    description: 'Application startup time',
  );

  print('Recording app start time: 1234.5ms');
  appStartTime.record(1234.5, attributes: {
    'app.version': AttributeValue.string('1.0.0'),
    'environment': AttributeValue.string('development'),
  });

  print('Waiting 30 seconds for multiple exports to Aspire Dashboard...');
  print('Check http://localhost:18888 for the metric');
  print('');

  // Keep the app running for 30 seconds to allow multiple periodic exports
  for (var i = 0; i < 6; i++) {
    await Future.delayed(const Duration(seconds: 5));
    print('Export ${i + 1}/6 should have occurred...');
  }

  print('\nShutting down...');
  await meterProvider.shutdown();
  print('Done!');
}
