import 'tracer.dart';

/// TracerProvider provides access to tracers.
abstract class TracerProvider {
  /// Gets a tracer with the given instrumentation scope.
  Tracer getTracer(
    String name, {
    String? version,
  });

  /// Shuts down the tracer provider and all associated processors.
  Future<void> shutdown();

  /// Forces all pending spans to be exported.
  Future<void> forceFlush();
}
