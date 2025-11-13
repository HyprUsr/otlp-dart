import 'dart:async';
import 'dart:math';
import 'package:otlp_dart/otlp_dart.dart';

void main() async {
  print('Starting continuous metrics demo...');
  print('This will continuously record metrics for 60 seconds');
  print('Check http://localhost:18888 to see metrics updating in real-time');
  print('');

  final resource = Resource.create(serviceName: 'continuous-metrics-test');
  final exporter = OtlpHttpMetricExporter.aspire(host: 'localhost', port: 18889);
  final reader = PeriodicMetricReader(
    exporter: exporter,
    resource: resource,
    scope: InstrumentationScope(name: 'test', version: '1.0.0'),
    interval: const Duration(seconds: 5), // Export every 5 seconds
  );
  final meterProvider = MeterProviderImpl(resource: resource, reader: reader);
  final meter = meterProvider.getMeter('test');

  // Create metrics
  final requestCounter = meter.createCounter(
    'http.requests',
    unit: 'requests',
    description: 'Total HTTP requests',
  );

  final requestDuration = meter.createHistogram(
    'http.duration',
    unit: 'ms',
    description: 'HTTP request duration',
  );

  final random = Random();
  var iteration = 0;

  print('Recording metrics continuously...');

  // Record metrics every 2 seconds for 60 seconds
  while (iteration < 30) {
    iteration++;

    // Simulate some requests
    final numRequests = 1 + random.nextInt(3);
    for (var i = 0; i < numRequests; i++) {
      final method = ['GET', 'POST', 'PUT'][random.nextInt(3)];
      final status = [200, 201, 400, 404, 500][random.nextInt(5)];
      final duration = 50 + random.nextDouble() * 450;

      requestCounter.add(1, attributes: {
        'method': AttributeValue.string(method),
        'status': AttributeValue.int(status),
      });

      requestDuration.record(duration, attributes: {
        'method': AttributeValue.string(method),
        'status': AttributeValue.int(status),
      });
    }

    print('Iteration $iteration: Recorded $numRequests requests');

    await Future.delayed(const Duration(seconds: 2));
  }

  print('\nStopping... Final flush and shutdown');
  await meterProvider.shutdown();
  print('Done! Metrics were exported throughout the 60 second period.');
  print('Check Aspire Dashboard to see the time-series data.');
}
