import 'dart:async';
import 'dart:math';
import 'package:otlp_dart/otlp_dart.dart';

/// Example demonstrating metrics export using the OTLP Dart library.
///
/// This example shows:
/// - Counter metrics for tracking HTTP requests
/// - Histogram metrics for tracking request duration and app start time
/// - Periodic export to an OTLP endpoint
void main() async {
  // Create resource with service information
  final resource = Resource(
    attributes: [
      Attribute('service.name', AttributeValue.string('metrics-example')),
      Attribute('service.version', AttributeValue.string('1.0.0')),
      Attribute('deployment.environment', AttributeValue.string('development')),
    ],
  );

  // Create OTLP exporter
  // For local testing with .NET Aspire Dashboard, use:
  // final exporter = OtlpHttpMetricExporter.aspire();
  //
  // For HTTP/1.1 endpoints:
  final exporter = OtlpHttpMetricExporter(
    endpoint: 'http://localhost:4318/v1/metrics',
    headers: {
      'x-custom-header': 'custom-value',
    },
  );

  // Create metric reader with 10 second export interval
  final reader = PeriodicMetricReader(
    exporter: exporter,
    resource: resource,
    scope: InstrumentationScope(
      name: 'metrics-example',
      version: '1.0.0',
    ),
    interval: const Duration(seconds: 10),
  );

  // Create meter provider
  final meterProvider = MeterProviderImpl(
    resource: resource,
    reader: reader,
  );

  // Get a meter
  final meter = meterProvider.getMeter(
    'metrics-example',
    version: '1.0.0',
  );

  // Create instruments
  final requestCounter = meter.createCounter(
    'http.server.requests',
    unit: 'requests',
    description: 'Total number of HTTP requests',
  );

  final requestDuration = meter.createHistogram(
    'http.server.duration',
    unit: 'ms',
    description: 'HTTP request duration in milliseconds',
  );

  final appStartTime = meter.createHistogram(
    'app.start.duration',
    unit: 'ms',
    description: 'Application startup duration in milliseconds',
  );

  // Record app start time
  final appStartDuration = 1234.5; // Simulated startup time
  appStartTime.record(
    appStartDuration,
    attributes: {
      'app.version': AttributeValue.string('1.0.0'),
    },
  );
  print('Recorded app start time: ${appStartDuration}ms');

  // Simulate HTTP requests
  print('\nSimulating HTTP requests...');
  final random = Random();

  // Simulate 20 HTTP requests
  for (var i = 0; i < 20; i++) {
    // Randomly choose an endpoint
    final endpoints = ['/api/users', '/api/products', '/api/orders'];
    final methods = ['GET', 'POST', 'PUT'];
    final statusCodes = [200, 201, 400, 404, 500];

    final endpoint = endpoints[random.nextInt(endpoints.length)];
    final method = methods[random.nextInt(methods.length)];
    final statusCode = statusCodes[random.nextInt(statusCodes.length)];

    // Simulate request duration (50-500ms)
    final duration = 50 + random.nextDouble() * 450;

    // Record metrics
    requestCounter.add(
      1,
      attributes: {
        'http.method': AttributeValue.string(method),
        'http.route': AttributeValue.string(endpoint),
        'http.status_code': AttributeValue.int(statusCode),
      },
    );

    requestDuration.record(
      duration,
      attributes: {
        'http.method': AttributeValue.string(method),
        'http.route': AttributeValue.string(endpoint),
        'http.status_code': AttributeValue.int(statusCode),
      },
    );

    print('  $method $endpoint -> $statusCode (${duration.toStringAsFixed(1)}ms)');

    // Small delay between requests
    await Future.delayed(const Duration(milliseconds: 100));
  }

  print('\nMetrics recorded. Waiting for export...');

  // Force flush to export immediately
  await meterProvider.forceFlush();
  print('Metrics exported successfully!');

  // Keep running for a bit to allow periodic exports
  print('\nKeeping application running for 15 seconds...');
  await Future.delayed(const Duration(seconds: 15));

  // Shutdown
  print('Shutting down...');
  await meterProvider.shutdown();
  print('Done!');
}
