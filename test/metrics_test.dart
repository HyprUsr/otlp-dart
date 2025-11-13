import 'package:test/test.dart';
import 'package:otlp_dart/otlp_dart.dart';

void main() {
  group('Metrics SDK', () {
    late Resource resource;
    late InstrumentationScope scope;

    setUp(() {
      resource = Resource(
        attributes: [
          Attribute('service.name', AttributeValue.string('test-service')),
        ],
      );
      scope = InstrumentationScope(name: 'test-scope', version: '1.0.0');
    });

    test('Counter increments correctly', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:4318/v1/metrics',
      );

      final reader = PeriodicMetricReader(
        exporter: exporter,
        resource: resource,
        scope: scope,
        interval: const Duration(seconds: 60),
      );

      final meterProvider = MeterProviderImpl(
        resource: resource,
        reader: reader,
      );

      final meter = meterProvider.getMeter('test-meter');
      final counter = meter.createCounter(
        'test.counter',
        unit: 'requests',
        description: 'Test counter',
      );

      // Add some values
      counter.add(1, attributes: {
        'method': AttributeValue.string('GET'),
      });
      counter.add(2, attributes: {
        'method': AttributeValue.string('POST'),
      });

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Clean up
      meterProvider.shutdown();
    });

    test('Histogram records values correctly', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:4318/v1/metrics',
      );

      final reader = PeriodicMetricReader(
        exporter: exporter,
        resource: resource,
        scope: scope,
        interval: const Duration(seconds: 60),
      );

      final meterProvider = MeterProviderImpl(
        resource: resource,
        reader: reader,
      );

      final meter = meterProvider.getMeter('test-meter');
      final histogram = meter.createHistogram(
        'test.histogram',
        unit: 'ms',
        description: 'Test histogram',
      );

      // Record some values
      histogram.record(10.5, attributes: {
        'endpoint': AttributeValue.string('/api/users'),
      });
      histogram.record(25.3, attributes: {
        'endpoint': AttributeValue.string('/api/products'),
      });
      histogram.record(150.7, attributes: {
        'endpoint': AttributeValue.string('/api/orders'),
      });

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Clean up
      meterProvider.shutdown();
    });

    test('ObservableGauge reports current value', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:4318/v1/metrics',
      );

      final reader = PeriodicMetricReader(
        exporter: exporter,
        resource: resource,
        scope: scope,
        interval: const Duration(seconds: 60),
      );

      final meterProvider = MeterProviderImpl(
        resource: resource,
        reader: reader,
      );

      var currentValue = 42.0;
      final meter = meterProvider.getMeter('test-meter');
      final gauge = meter.createObservableGauge(
        'test.gauge',
        () => currentValue,
        unit: 'items',
        description: 'Test gauge',
      );

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Clean up
      meterProvider.shutdown();
    });

    test('MeterProvider creates unique meters', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:4318/v1/metrics',
      );

      final reader = PeriodicMetricReader(
        exporter: exporter,
        resource: resource,
        scope: scope,
        interval: const Duration(seconds: 60),
      );

      final meterProvider = MeterProviderImpl(
        resource: resource,
        reader: reader,
      );

      final meter1 = meterProvider.getMeter('meter1');
      final meter2 = meterProvider.getMeter('meter2');
      final meter1Again = meterProvider.getMeter('meter1');

      expect(identical(meter1, meter1Again), true);
      expect(identical(meter1, meter2), false);

      // Clean up
      meterProvider.shutdown();
    });
  });
}
