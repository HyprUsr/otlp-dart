import 'recording_span.dart';

/// SpanExporter exports spans to a backend.
abstract class SpanExporter {
  /// Exports a batch of spans.
  Future<void> export(List<RecordingSpan> spans);

  /// Ensures all pending exports are completed.
  Future<void> forceFlush();

  /// Shuts down the exporter.
  Future<void> shutdown();
}
