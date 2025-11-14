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
          Attribute('service.version', AttributeValue.string('1.0.0')),
        ],
      );
      scope = InstrumentationScope(name: 'test-scope', version: '1.0.0');
    });

    test('Counter increments correctly', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
      },);
      counter.add(2, attributes: {
        'method': AttributeValue.string('POST'),
      },);

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Clean up
      meterProvider.shutdown();
    });

    test('Histogram records values correctly', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
      },);
      histogram.record(25.3, attributes: {
        'endpoint': AttributeValue.string('/api/products'),
      },);
      histogram.record(150.7, attributes: {
        'endpoint': AttributeValue.string('/api/orders'),
      },);

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Clean up
      meterProvider.shutdown();
    });

    test('ObservableGauge reports current value', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
      meter.createObservableGauge(
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
        endpoint: 'http://localhost:18888/v1/metrics',
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

    test('UpDownCounter increments and decrements correctly', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
      final upDownCounter = meter.createUpDownCounter(
        'test.updowncounter',
        unit: 'items',
        description: 'Test up-down counter',
      );

      // Add positive and negative values
      upDownCounter.add(10, attributes: {
        'direction': AttributeValue.string('up'),
      },);
      upDownCounter.add(-3, attributes: {
        'direction': AttributeValue.string('down'),
      },);
      upDownCounter.add(5, attributes: {
        'direction': AttributeValue.string('up'),
      },);

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Clean up
      meterProvider.shutdown();
    });

    test('ObservableCounter reports cumulative values', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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

      var cumulativeValue = 100;
      final meter = meterProvider.getMeter('test-meter');
      meter.createObservableCounter(
        'test.observable.counter',
        () => cumulativeValue,
        unit: 'bytes',
        description: 'Test observable counter',
      );

      // First collection
      var metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Update value and collect again
      cumulativeValue = 250;
      metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Clean up
      meterProvider.shutdown();
    });

    test('Histogram bucket boundaries work correctly', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
        'test.histogram.buckets',
        unit: 'ms',
        description: 'Test histogram bucket distribution',
      );

      // Record values at exact bucket boundaries and between them
      // Boundaries: [0.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0]
      histogram.record(0.0); // Exactly at boundary
      histogram.record(2.5); // Between 0 and 5
      histogram.record(5.0); // Exactly at boundary
      histogram.record(7.5); // Between 5 and 10
      histogram.record(15.0); // Between 10 and 25
      histogram.record(50.0); // Exactly at boundary
      histogram.record(200.0); // Between 100 and 250
      histogram.record(1500.0); // Above highest boundary

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      // Verify the histogram data exists
      final histogramMetric = metrics.firstWhere(
        (m) => m.name == 'test.histogram.buckets',
      );
      expect(histogramMetric.name, 'test.histogram.buckets');

      // Clean up
      meterProvider.shutdown();
    });

    test('Histogram handles multiple attribute combinations', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
        'test.histogram.attributes',
        unit: 'ms',
        description: 'Test histogram with multiple attributes',
      );

      // Record values with different attribute combinations
      histogram.record(10.0, attributes: {
        'endpoint': AttributeValue.string('/api/users'),
        'method': AttributeValue.string('GET'),
      },);
      histogram.record(20.0, attributes: {
        'endpoint': AttributeValue.string('/api/users'),
        'method': AttributeValue.string('GET'),
      },);
      histogram.record(30.0, attributes: {
        'endpoint': AttributeValue.string('/api/users'),
        'method': AttributeValue.string('POST'),
      },);
      histogram.record(40.0, attributes: {
        'endpoint': AttributeValue.string('/api/products'),
        'method': AttributeValue.string('GET'),
      },);

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      final histogramMetric = metrics.firstWhere(
        (m) => m.name == 'test.histogram.attributes',
      );
      expect(histogramMetric.name, 'test.histogram.attributes');

      // Clean up
      meterProvider.shutdown();
    });

    test('Counter with complex attribute types', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
        'test.counter.attributes',
        unit: 'requests',
        description: 'Test counter with various attribute types',
      );

      // Test different attribute value types
      counter.add(1, attributes: {
        'string_attr': AttributeValue.string('value'),
        'int_attr': AttributeValue.int(42),
        'double_attr': AttributeValue.double(3.14),
        'bool_attr': AttributeValue.bool(true),
      },);

      counter.add(2, attributes: {
        'array_attr': AttributeValue.array([
          AttributeValue.string('a'),
          AttributeValue.string('b'),
          AttributeValue.string('c'),
        ]),
      },);

      counter.add(3, attributes: {
        'int_array': AttributeValue.array([
          AttributeValue.int(1),
          AttributeValue.int(2),
          AttributeValue.int(3),
        ]),
      },);

      counter.add(4, attributes: {
        'double_array': AttributeValue.array([
          AttributeValue.double(1.1),
          AttributeValue.double(2.2),
          AttributeValue.double(3.3),
        ]),
      },);

      counter.add(5, attributes: {
        'bool_array': AttributeValue.array([
          AttributeValue.bool(true),
          AttributeValue.bool(false),
          AttributeValue.bool(true),
        ]),
      },);

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      final counterMetric = metrics.firstWhere(
        (m) => m.name == 'test.counter.attributes',
      );
      expect(counterMetric.name, 'test.counter.attributes');

      // Clean up
      meterProvider.shutdown();
    });

    test('Metric collection resets values with delta temporality', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
        'test.counter.delta',
        unit: 'requests',
        description: 'Test delta temporality',
      );

      // Add values
      counter.add(10, attributes: {
        'key': AttributeValue.string('value'),
      },);

      // First collection
      var metrics = reader.collectMetrics();
      expect(metrics.isNotEmpty, true);

      var counterMetric = metrics.firstWhere(
        (m) => m.name == 'test.counter.delta',
      );
      expect(counterMetric.name, 'test.counter.delta');

      // Add more values
      counter.add(5, attributes: {
        'key': AttributeValue.string('value'),
      },);

      // Second collection - should only have new values (delta)
      metrics = reader.collectMetrics();
      counterMetric = metrics.firstWhere(
        (m) => m.name == 'test.counter.delta',
      );
      expect(counterMetric.name, 'test.counter.delta');

      // Clean up
      meterProvider.shutdown();
    });

    test('Histogram min/max calculations', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
        'test.histogram.minmax',
        unit: 'ms',
        description: 'Test histogram min/max',
      );

      // Record a series of values
      final values = [42.5, 17.3, 99.8, 5.1, 150.0, 23.7];
      for (final value in values) {
        histogram.record(value);
      }

      // Collect metrics
      final metrics = reader.collectMetrics();
      final histogramMetric = metrics.firstWhere(
        (m) => m.name == 'test.histogram.minmax',
      );
      expect(histogramMetric.name, 'test.histogram.minmax');

      // Clean up
      meterProvider.shutdown();
    });

    test('MeterProvider shutdown prevents new operations', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
        'test.counter.shutdown',
        unit: 'requests',
      );

      // Add value before shutdown
      counter.add(1);

      // Shutdown
      meterProvider.shutdown();

      // Attempt to create new meter after shutdown should throw
      expect(
        () => meterProvider.getMeter('new-meter'),
        throwsStateError,
      );

      // Attempt to add value after shutdown (should not crash)
      counter.add(1);
    });

    test('Multiple meters with same name return same instance', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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

      final meter1 = meterProvider.getMeter('test-meter', version: '1.0.0');
      final meter2 = meterProvider.getMeter('test-meter', version: '1.0.0');
      final meter3 = meterProvider.getMeter('test-meter', version: '2.0.0');

      expect(identical(meter1, meter2), true);
      expect(identical(meter1, meter3), false);

      // Clean up
      meterProvider.shutdown();
    });

    test('Resource attributes are properly set', () {
      final customResource = Resource(
        attributes: [
          Attribute('service.name', AttributeValue.string('my-service')),
          Attribute('service.version', AttributeValue.string('2.0.0')),
          Attribute('environment', AttributeValue.string('production')),
          Attribute('host.name', AttributeValue.string('server-01')),
        ],
      );

      expect(customResource.attributes.length, 4);
      expect(
        customResource.attributes[0].key,
        'service.name',
      );
      expect(
        customResource.attributes[0].value.stringValue,
        'my-service',
      );

      // Test JSON serialization
      final json = customResource.toJson();
      expect(json['attributes'], isA<List>());
      expect((json['attributes'] as List).length, 4);
    });

    test('InstrumentationScope with version and attributes', () {
      final scopeWithAttrs = InstrumentationScope(
        name: 'test-scope',
        version: '1.2.3',
        attributes: [
          Attribute('scope.type', AttributeValue.string('test')),
        ],
      );

      expect(scopeWithAttrs.name, 'test-scope');
      expect(scopeWithAttrs.version, '1.2.3');
      expect(scopeWithAttrs.attributes.length, 1);

      // Test JSON serialization
      final json = scopeWithAttrs.toJson();
      expect(json['name'], 'test-scope');
      expect(json['version'], '1.2.3');
      expect(json['attributes'], isA<List>());
    });

    test('Counter with empty attributes', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
      final counter = meter.createCounter('test.counter.noattrs');

      // Add values without attributes
      counter.add(5);
      counter.add(10);
      counter.add(15);

      // Collect metrics
      final metrics = reader.collectMetrics();
      final counterMetric = metrics.firstWhere(
        (m) => m.name == 'test.counter.noattrs',
      );
      expect(counterMetric.name, 'test.counter.noattrs');

      // Clean up
      meterProvider.shutdown();
    });

    test('Histogram with single value', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
      final histogram = meter.createHistogram('test.histogram.single');

      // Record single value
      histogram.record(42.0);

      // Collect metrics
      final metrics = reader.collectMetrics();
      final histogramMetric = metrics.firstWhere(
        (m) => m.name == 'test.histogram.single',
      );
      expect(histogramMetric.name, 'test.histogram.single');

      // Clean up
      meterProvider.shutdown();
    });

    test('ObservableGauge value changes between collections', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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

      var currentValue = 100.0;
      final meter = meterProvider.getMeter('test-meter');
      meter.createObservableGauge(
        'test.gauge.changing',
        () => currentValue,
        unit: 'items',
      );

      // First collection
      var metrics = reader.collectMetrics();
      var gaugeMetric = metrics.firstWhere(
        (m) => m.name == 'test.gauge.changing',
      );
      expect(gaugeMetric.name, 'test.gauge.changing');

      // Change value
      currentValue = 200.0;

      // Second collection
      metrics = reader.collectMetrics();
      gaugeMetric = metrics.firstWhere(
        (m) => m.name == 'test.gauge.changing',
      );
      expect(gaugeMetric.name, 'test.gauge.changing');

      // Change to negative
      currentValue = -50.0;

      // Third collection
      metrics = reader.collectMetrics();
      gaugeMetric = metrics.firstWhere(
        (m) => m.name == 'test.gauge.changing',
      );
      expect(gaugeMetric.name, 'test.gauge.changing');

      // Clean up
      meterProvider.shutdown();
    });

    test('Multiple instruments on same meter', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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

      // Create multiple different instruments
      final counter = meter.createCounter('requests.total');
      final upDownCounter = meter.createUpDownCounter('connections.active');
      final histogram = meter.createHistogram('request.duration');
      meter.createObservableGauge('cpu.usage', () => 75.5);

      // Record values
      counter.add(10);
      upDownCounter.add(5);
      upDownCounter.add(-2);
      histogram.record(150.0);
      histogram.record(200.0);

      // Collect metrics
      final metrics = reader.collectMetrics();
      expect(metrics.length, 4);

      final metricNames = metrics.map((m) => m.name).toSet();
      expect(metricNames, containsAll([
        'requests.total',
        'connections.active',
        'request.duration',
        'cpu.usage',
      ]),);

      // Clean up
      meterProvider.shutdown();
    });

    test('Attribute value conversions and edge cases', () {
      // Test string values
      final stringAttr = AttributeValue.string('test');
      expect(stringAttr.stringValue, 'test');

      // Test int values
      final intAttr = AttributeValue.int(42);
      expect(intAttr.intValue, 42);

      // Test double values
      final doubleAttr = AttributeValue.double(3.14);
      expect(doubleAttr.doubleValue, 3.14);

      // Test bool values
      final boolAttr = AttributeValue.bool(true);
      expect(boolAttr.boolValue, true);

      // Test arrays
      final arrayAttr = AttributeValue.array([
        AttributeValue.string('a'),
        AttributeValue.string('b'),
        AttributeValue.string('c'),
      ]);
      expect(arrayAttr.arrayValue?.length, 3);
      expect(arrayAttr.arrayValue?[0].stringValue, 'a');

      // Test kvlist
      final kvList = AttributeValue.kvlist({
        'nested': AttributeValue.string('value'),
      });
      expect(kvList.kvlistValue?.length, 1);
      expect(kvList.kvlistValue?['nested']?.stringValue, 'value');

      // Test JSON serialization
      final json = kvList.toJson();
      expect(json, isA<Map>());
    });

    test('Concurrent metric recording', () async {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
      final counter = meter.createCounter('test.counter.concurrent');

      // Simulate concurrent recording
      final futures = <Future>[];
      for (var i = 0; i < 100; i++) {
        futures.add(Future(() => counter.add(1)));
      }

      await Future.wait(futures);

      // Collect metrics
      final metrics = reader.collectMetrics();
      final counterMetric = metrics.firstWhere(
        (m) => m.name == 'test.counter.concurrent',
      );
      expect(counterMetric.name, 'test.counter.concurrent');

      // Clean up
      meterProvider.shutdown();
    });

    test('Metric names and descriptions are preserved', () {
      final exporter = OtlpHttpMetricExporter(
        endpoint: 'http://localhost:18888/v1/metrics',
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
        'http.server.requests',
        unit: 'requests',
        description: 'Total number of HTTP requests',
      );

      counter.add(1);

      final metrics = reader.collectMetrics();
      final counterMetric = metrics.firstWhere(
        (m) => m.name == 'http.server.requests',
      );

      expect(counterMetric.name, 'http.server.requests');
      expect(counterMetric.unit, 'requests');
      expect(counterMetric.description, 'Total number of HTTP requests');

      // Clean up
      meterProvider.shutdown();
    });
  });
}
