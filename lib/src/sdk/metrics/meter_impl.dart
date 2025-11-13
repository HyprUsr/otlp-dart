import '../../api/metrics/meter.dart';
import '../../sdk/common/attribute.dart';
import '../../sdk/resource/resource.dart';
import 'metric_data.dart';
import 'metric_reader.dart';

/// Implementation of the Meter interface.
class MeterImpl implements Meter {
  final InstrumentationScope scope;
  final Resource resource;
  final MetricReader reader;
  final Map<String, _CounterImpl> _counters = {};
  final Map<String, _HistogramImpl> _histograms = {};
  final Map<String, _ObservableGaugeImpl> _observableGauges = {};

  MeterImpl({
    required this.scope,
    required this.resource,
    required this.reader,
  });

  @override
  Counter createCounter(String name, {String? unit, String? description}) {
    final key = '${scope.name}:$name';
    return _counters.putIfAbsent(key, () {
      final counter = _CounterImpl(
        name: name,
        unit: unit,
        description: description,
      );
      _registerMetric(key, counter._metricData);
      return counter;
    });
  }

  @override
  UpDownCounter createUpDownCounter(String name,
      {String? unit, String? description}) {
    // For simplicity, treating UpDownCounter like Counter for now
    return createCounter(name, unit: unit, description: description)
        as UpDownCounter;
  }

  @override
  Histogram createHistogram(String name, {String? unit, String? description}) {
    final key = '${scope.name}:$name';
    return _histograms.putIfAbsent(key, () {
      final histogram = _HistogramImpl(
        name: name,
        unit: unit,
        description: description,
      );
      _registerMetric(key, histogram._metricData);
      return histogram;
    });
  }

  @override
  ObservableGauge createObservableGauge(
    String name,
    double Function() callback, {
    String? unit,
    String? description,
  }) {
    final key = '${scope.name}:$name';
    return _observableGauges.putIfAbsent(key, () {
      final gauge = _ObservableGaugeImpl(
        name: name,
        callback: callback,
        unit: unit,
        description: description,
      );
      _registerMetric(key, gauge._metricData);
      return gauge;
    });
  }

  @override
  ObservableCounter createObservableCounter(
    String name,
    int Function() callback, {
    String? unit,
    String? description,
  }) {
    // For simplicity, converting to double and using gauge
    return createObservableGauge(name, () => callback().toDouble(),
        unit: unit, description: description) as ObservableCounter;
  }

  void _registerMetric(String key, MetricData metricData) {
    reader.registerMetric(key, metricData);
  }
}

class _CounterImpl implements Counter {
  final String name;
  final String? unit;
  final String? description;
  int _value = 0;
  final Map<String, AttributeValue> _lastAttributes = {};

  _CounterImpl({
    required this.name,
    this.unit,
    this.description,
  });

  @override
  void add(int value, {Map<String, AttributeValue>? attributes}) {
    if (value < 0) {
      throw ArgumentError('Counter value must be non-negative');
    }
    _value += value;
    if (attributes != null) {
      _lastAttributes.addAll(attributes);
    }
  }

  MetricData get _metricData {
    final now = DateTime.now();
    final timeNanos = now.microsecondsSinceEpoch * 1000;

    return SumData(
      name: name,
      description: description,
      unit: unit,
      dataPoints: [
        DataPoint(
          value: _value.toDouble(),
          startTimeUnixNano: timeNanos,
          timeUnixNano: timeNanos,
          attributes: _lastAttributes.entries
              .map((e) => Attribute(e.key, e.value))
              .toList(),
        ),
      ],
      isMonotonic: true,
    );
  }
}

class _HistogramImpl implements Histogram {
  final String name;
  final String? unit;
  final String? description;
  final List<double> _values = [];
  final Map<String, AttributeValue> _lastAttributes = {};

  _HistogramImpl({
    required this.name,
    this.unit,
    this.description,
  });

  @override
  void record(double value, {Map<String, AttributeValue>? attributes}) {
    _values.add(value);
    if (attributes != null) {
      _lastAttributes.addAll(attributes);
    }
  }

  MetricData get _metricData {
    final now = DateTime.now();
    final timeNanos = now.microsecondsSinceEpoch * 1000;

    if (_values.isEmpty) {
      return HistogramData(
        name: name,
        description: description,
        unit: unit,
        dataPoints: [],
      );
    }

    final sum = _values.reduce((a, b) => a + b);
    final count = _values.length;
    final min = _values.reduce((a, b) => a < b ? a : b);
    final max = _values.reduce((a, b) => a > b ? a : b);

    // Create simple histogram buckets
    final bounds = [0.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0];
    final buckets = List<int>.filled(bounds.length + 1, 0);

    for (final value in _values) {
      var bucketIndex = bounds.length;
      for (var i = 0; i < bounds.length; i++) {
        if (value < bounds[i]) {
          bucketIndex = i;
          break;
        }
      }
      buckets[bucketIndex]++;
    }

    return HistogramData(
      name: name,
      description: description,
      unit: unit,
      dataPoints: [
        HistogramDataPoint(
          count: count,
          sum: sum,
          min: min,
          max: max,
          startTimeUnixNano: timeNanos,
          timeUnixNano: timeNanos,
          bucketCounts: buckets,
          explicitBounds: bounds,
          attributes: _lastAttributes.entries
              .map((e) => Attribute(e.key, e.value))
              .toList(),
        ),
      ],
    );
  }
}

class _ObservableGaugeImpl implements ObservableGauge {
  final String name;
  final double Function() callback;
  final String? unit;
  final String? description;

  _ObservableGaugeImpl({
    required this.name,
    required this.callback,
    this.unit,
    this.description,
  });

  MetricData get _metricData {
    final now = DateTime.now();
    final timeNanos = now.microsecondsSinceEpoch * 1000;

    return GaugeData(
      name: name,
      description: description,
      unit: unit,
      dataPoints: [
        DataPoint(
          value: callback(),
          startTimeUnixNano: timeNanos,
          timeUnixNano: timeNanos,
          attributes: [],
        ),
      ],
    );
  }
}
