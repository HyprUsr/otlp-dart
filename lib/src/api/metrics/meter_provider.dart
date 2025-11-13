import 'meter.dart';

/// MeterProvider provides access to meters.
abstract class MeterProvider {
  /// Gets a meter with the given instrumentation scope.
  Meter getMeter(
    String name, {
    String? version,
  });

  /// Shuts down the meter provider and all associated components.
  Future<void> shutdown();

  /// Forces all pending metrics to be exported.
  Future<void> forceFlush();
}
