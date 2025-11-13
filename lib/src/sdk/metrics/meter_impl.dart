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
  final Map<String, _UpDownCounterImpl> _upDownCounters = {};
  final Map<String, _HistogramImpl> _histograms = {};
  final Map<String, _ObservableGaugeImpl> _observableGauges = {};
  final Map<String, _ObservableCounterImpl> _observableCounters = {};

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
      _registerMetric(key, () => counter._metricData);
      return counter;
    });
  }

  @override
  UpDownCounter createUpDownCounter(String name,
      {String? unit, String? description}) {
    final key = '${scope.name}:$name';
    return _upDownCounters.putIfAbsent(key, () {
      final counter = _UpDownCounterImpl(
        name: name,
        unit: unit,
        description: description,
      );
      _registerMetric(key, () => counter._metricData);
      return counter;
    });
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
      _registerMetric(key, () => histogram._metricData);
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
      _registerMetric(key, () => gauge._metricData);
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
    final key = '${scope.name}:$name';
    return _observableCounters.putIfAbsent(key, () {
      final counter = _ObservableCounterImpl(
        name: name,
        callback: callback,
        unit: unit,
        description: description,
      );
      _registerMetric(key, () => counter._metricData);
      return counter;
    });
  }

  void _registerMetric(String key, MetricData Function() metricProducer) {
    reader.registerMetric(key, metricProducer);
  }
}

class _CounterImpl implements Counter {
  final String name;
  final String? unit;
  final String? description;
  final Map<String, int> _valuesByAttributes = {};
  int _startTimeUnixNano;

  _CounterImpl({
    required this.name,
    this.unit,
    this.description,
  }) : _startTimeUnixNano = DateTime.now().microsecondsSinceEpoch * 1000;

  @override
  void add(int value, {Map<String, AttributeValue>? attributes}) {
    if (value < 0) {
      throw ArgumentError('Counter value must be non-negative');
    }
    final key = _attributeKey(attributes ?? {});
    _valuesByAttributes[key] = (_valuesByAttributes[key] ?? 0) + value;
  }

  String _attributeKey(Map<String, AttributeValue> attributes) {
    final sorted = attributes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => '${e.key}=${_attributeValueToString(e.value)}').join(',');
  }

  String _attributeValueToString(AttributeValue value) {
    if (value.stringValue != null) return 's:${value.stringValue}';
    if (value.intValue != null) return 'i:${value.intValue}';
    if (value.doubleValue != null) return 'd:${value.doubleValue}';
    if (value.boolValue != null) return 'b:${value.boolValue}';
    return '';
  }

  Map<String, AttributeValue> _parseAttributeKey(String key) {
    if (key.isEmpty) return {};
    final result = <String, AttributeValue>{};
    for (final pair in key.split(',')) {
      final eqIndex = pair.indexOf('=');
      if (eqIndex > 0) {
        final attrKey = pair.substring(0, eqIndex);
        final attrValue = pair.substring(eqIndex + 1);

        if (attrValue.startsWith('s:')) {
          result[attrKey] = AttributeValue.string(attrValue.substring(2));
        } else if (attrValue.startsWith('i:')) {
          result[attrKey] = AttributeValue.int(int.parse(attrValue.substring(2)));
        } else if (attrValue.startsWith('d:')) {
          result[attrKey] = AttributeValue.double(double.parse(attrValue.substring(2)));
        } else if (attrValue.startsWith('b:')) {
          result[attrKey] = AttributeValue.bool(attrValue.substring(2) == 'true');
        }
      }
    }
    return result;
  }

  MetricData get _metricData {
    final now = DateTime.now();
    final timeNanos = now.microsecondsSinceEpoch * 1000;
    final startTime = _startTimeUnixNano;

    // For DELTA temporality, we need to collect and reset
    final dataPoints = _valuesByAttributes.entries.map((entry) {
      final attrs = _parseAttributeKey(entry.key);
      return DataPoint(
        value: entry.value.toDouble(),
        startTimeUnixNano: startTime,
        timeUnixNano: timeNanos,
        attributes: attrs.entries
            .map((e) => Attribute(e.key, e.value))
            .toList(),
      );
    }).toList();

    // Reset for delta temporality and update start time
    _valuesByAttributes.clear();
    _startTimeUnixNano = timeNanos;

    return SumData(
      name: name,
      description: description,
      unit: unit,
      dataPoints: dataPoints,
      isMonotonic: true,
    );
  }
}

class _UpDownCounterImpl implements UpDownCounter {
  final String name;
  final String? unit;
  final String? description;
  final Map<String, int> _valuesByAttributes = {};
  int _startTimeUnixNano;

  _UpDownCounterImpl({
    required this.name,
    this.unit,
    this.description,
  }) : _startTimeUnixNano = DateTime.now().microsecondsSinceEpoch * 1000;

  @override
  void add(int value, {Map<String, AttributeValue>? attributes}) {
    // UpDownCounter allows negative values
    final key = _attributeKey(attributes ?? {});
    _valuesByAttributes[key] = (_valuesByAttributes[key] ?? 0) + value;
  }

  String _attributeKey(Map<String, AttributeValue> attributes) {
    final sorted = attributes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => '${e.key}=${_attributeValueToString(e.value)}').join(',');
  }

  String _attributeValueToString(AttributeValue value) {
    if (value.stringValue != null) return 's:${value.stringValue}';
    if (value.intValue != null) return 'i:${value.intValue}';
    if (value.doubleValue != null) return 'd:${value.doubleValue}';
    if (value.boolValue != null) return 'b:${value.boolValue}';
    return '';
  }

  Map<String, AttributeValue> _parseAttributeKey(String key) {
    if (key.isEmpty) return {};
    final result = <String, AttributeValue>{};
    for (final pair in key.split(',')) {
      final eqIndex = pair.indexOf('=');
      if (eqIndex > 0) {
        final attrKey = pair.substring(0, eqIndex);
        final attrValue = pair.substring(eqIndex + 1);

        if (attrValue.startsWith('s:')) {
          result[attrKey] = AttributeValue.string(attrValue.substring(2));
        } else if (attrValue.startsWith('i:')) {
          result[attrKey] = AttributeValue.int(int.parse(attrValue.substring(2)));
        } else if (attrValue.startsWith('d:')) {
          result[attrKey] = AttributeValue.double(double.parse(attrValue.substring(2)));
        } else if (attrValue.startsWith('b:')) {
          result[attrKey] = AttributeValue.bool(attrValue.substring(2) == 'true');
        }
      }
    }
    return result;
  }

  MetricData get _metricData {
    final now = DateTime.now();
    final timeNanos = now.microsecondsSinceEpoch * 1000;
    final startTime = _startTimeUnixNano;

    // For DELTA temporality, we need to collect and reset
    final dataPoints = _valuesByAttributes.entries.map((entry) {
      final attrs = _parseAttributeKey(entry.key);
      return DataPoint(
        value: entry.value.toDouble(),
        startTimeUnixNano: startTime,
        timeUnixNano: timeNanos,
        attributes: attrs.entries
            .map((e) => Attribute(e.key, e.value))
            .toList(),
      );
    }).toList();

    // Reset for delta temporality and update start time
    _valuesByAttributes.clear();
    _startTimeUnixNano = timeNanos;

    return SumData(
      name: name,
      description: description,
      unit: unit,
      dataPoints: dataPoints,
      isMonotonic: false, // UpDownCounter is not monotonic
    );
  }
}

class _HistogramImpl implements Histogram {
  final String name;
  final String? unit;
  final String? description;
  final Map<String, List<double>> _valuesByAttributes = {};
  int _startTimeUnixNano;

  _HistogramImpl({
    required this.name,
    this.unit,
    this.description,
  }) : _startTimeUnixNano = DateTime.now().microsecondsSinceEpoch * 1000;

  @override
  void record(double value, {Map<String, AttributeValue>? attributes}) {
    final key = _attributeKey(attributes ?? {});
    _valuesByAttributes.putIfAbsent(key, () => []).add(value);
  }

  String _attributeKey(Map<String, AttributeValue> attributes) {
    final sorted = attributes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => '${e.key}=${_attributeValueToString(e.value)}').join(',');
  }

  String _attributeValueToString(AttributeValue value) {
    if (value.stringValue != null) return 's:${value.stringValue}';
    if (value.intValue != null) return 'i:${value.intValue}';
    if (value.doubleValue != null) return 'd:${value.doubleValue}';
    if (value.boolValue != null) return 'b:${value.boolValue}';
    return '';
  }

  Map<String, AttributeValue> _parseAttributeKey(String key) {
    if (key.isEmpty) return {};
    final result = <String, AttributeValue>{};
    for (final pair in key.split(',')) {
      final eqIndex = pair.indexOf('=');
      if (eqIndex > 0) {
        final attrKey = pair.substring(0, eqIndex);
        final attrValue = pair.substring(eqIndex + 1);

        if (attrValue.startsWith('s:')) {
          result[attrKey] = AttributeValue.string(attrValue.substring(2));
        } else if (attrValue.startsWith('i:')) {
          result[attrKey] = AttributeValue.int(int.parse(attrValue.substring(2)));
        } else if (attrValue.startsWith('d:')) {
          result[attrKey] = AttributeValue.double(double.parse(attrValue.substring(2)));
        } else if (attrValue.startsWith('b:')) {
          result[attrKey] = AttributeValue.bool(attrValue.substring(2) == 'true');
        }
      }
    }
    return result;
  }

  MetricData get _metricData {
    final now = DateTime.now();
    final timeNanos = now.microsecondsSinceEpoch * 1000;
    final startTime = _startTimeUnixNano;

    final dataPoints = <HistogramDataPoint>[];

    for (final entry in _valuesByAttributes.entries) {
      final values = entry.value;
      if (values.isEmpty) continue;

      final sum = values.reduce((a, b) => a + b);
      final count = values.length;
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);

      // Create simple histogram buckets
      final bounds = [0.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0];
      final buckets = List<int>.filled(bounds.length + 1, 0);

      for (final value in values) {
        var bucketIndex = bounds.length;
        for (var i = 0; i < bounds.length; i++) {
          if (value < bounds[i]) {
            bucketIndex = i;
            break;
          }
        }
        buckets[bucketIndex]++;
      }

      final attrs = _parseAttributeKey(entry.key);
      dataPoints.add(
        HistogramDataPoint(
          count: count,
          sum: sum,
          min: min,
          max: max,
          startTimeUnixNano: startTime,
          timeUnixNano: timeNanos,
          bucketCounts: buckets,
          explicitBounds: bounds,
          attributes: attrs.entries
              .map((e) => Attribute(e.key, e.value))
              .toList(),
        ),
      );
    }

    // Reset for delta temporality and update start time
    _valuesByAttributes.clear();
    _startTimeUnixNano = timeNanos;

    return HistogramData(
      name: name,
      description: description,
      unit: unit,
      dataPoints: dataPoints,
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

class _ObservableCounterImpl implements ObservableCounter {
  final String name;
  final int Function() callback;
  final String? unit;
  final String? description;
  int _startTimeUnixNano;

  _ObservableCounterImpl({
    required this.name,
    required this.callback,
    this.unit,
    this.description,
  }) : _startTimeUnixNano = DateTime.now().microsecondsSinceEpoch * 1000;

  MetricData get _metricData {
    final now = DateTime.now();
    final timeNanos = now.microsecondsSinceEpoch * 1000;
    final startTime = _startTimeUnixNano;

    // Update start time for next collection
    _startTimeUnixNano = timeNanos;

    return SumData(
      name: name,
      description: description,
      unit: unit,
      dataPoints: [
        DataPoint(
          value: callback().toDouble(),
          startTimeUnixNano: startTime,
          timeUnixNano: timeNanos,
          attributes: [],
        ),
      ],
      isMonotonic: true, // ObservableCounter is monotonic
    );
  }
}
