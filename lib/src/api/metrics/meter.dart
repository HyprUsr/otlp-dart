import '../../sdk/common/attribute.dart';

/// Meter is the interface for creating metric instruments.
abstract class Meter {
  /// Creates a counter instrument.
  Counter createCounter(String name, {String? unit, String? description});

  /// Creates an up-down counter instrument.
  UpDownCounter createUpDownCounter(String name,
      {String? unit, String? description,});

  /// Creates a histogram instrument.
  Histogram createHistogram(String name, {String? unit, String? description});

  /// Creates an observable gauge.
  ObservableGauge createObservableGauge(
    String name,
    double Function() callback, {
    String? unit,
    String? description,
  });

  /// Creates an observable counter.
  ObservableCounter createObservableCounter(
    String name,
    int Function() callback, {
    String? unit,
    String? description,
  });
}

/// Counter is a monotonically increasing metric.
abstract class Counter {
  void add(int value, {Map<String, AttributeValue>? attributes});
}

/// UpDownCounter is a metric that can increase or decrease.
abstract class UpDownCounter {
  void add(int value, {Map<String, AttributeValue>? attributes});
}

/// Histogram records a distribution of values.
abstract class Histogram {
  void record(double value, {Map<String, AttributeValue>? attributes});
}

/// ObservableGauge represents a current value that is observed.
abstract class ObservableGauge {
  // Callback is registered at creation time
}

/// ObservableCounter represents a monotonically increasing value that is observed.
abstract class ObservableCounter {
  // Callback is registered at creation time
}
