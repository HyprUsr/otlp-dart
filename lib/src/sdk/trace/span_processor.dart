import 'dart:async';
import 'recording_span.dart';
import 'span_exporter.dart';

/// SpanProcessor handles span lifecycle events.
abstract class SpanProcessor {
  /// Called when a span is started.
  void onStart(RecordingSpan span);

  /// Called when a span is ended.
  void onEnd(RecordingSpan span);

  /// Exports all pending spans and shuts down the processor.
  Future<void> shutdown();

  /// Exports all pending spans.
  Future<void> forceFlush();
}

/// NoopSpanProcessor does nothing with spans.
class NoopSpanProcessor implements SpanProcessor {
  @override
  void onStart(RecordingSpan span) {}

  @override
  void onEnd(RecordingSpan span) {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<void> forceFlush() async {}
}

/// SimpleSpanProcessor exports spans immediately when they end.
class SimpleSpanProcessor implements SpanProcessor {

  SimpleSpanProcessor(this.exporter);
  final SpanExporter exporter;

  @override
  void onStart(RecordingSpan span) {}

  @override
  void onEnd(RecordingSpan span) {
    exporter.export([span]);
  }

  @override
  Future<void> shutdown() async {
    await exporter.shutdown();
  }

  @override
  Future<void> forceFlush() async {
    await exporter.forceFlush();
  }
}

/// BatchSpanProcessor batches spans and exports them periodically.
class BatchSpanProcessor implements SpanProcessor {

  BatchSpanProcessor({
    required this.exporter,
    this.maxQueueSize = 2048,
    this.maxExportBatchSize = 512,
    this.scheduledDelayMillis = const Duration(milliseconds: 5000),
  }) {
    _startTimer();
  }
  final SpanExporter exporter;
  final int maxQueueSize;
  final int maxExportBatchSize;
  final Duration scheduledDelayMillis;

  final List<RecordingSpan> _queue = [];
  Timer? _timer;
  bool _shutdown = false;

  @override
  void onStart(RecordingSpan span) {}

  @override
  void onEnd(RecordingSpan span) {
    if (_shutdown) {
      return;
    }

    if (_queue.length >= maxQueueSize) {
      // Queue is full, drop the span
      return;
    }

    _queue.add(span);

    if (_queue.length >= maxExportBatchSize) {
      _exportBatch();
    }
  }

  @override
  Future<void> shutdown() async {
    if (_shutdown) return;

    _shutdown = true;
    _timer?.cancel();
    // Drain the entire queue
    while (_queue.isNotEmpty) {
      await _exportBatch();
    }
    await exporter.shutdown();
  }

  @override
  Future<void> forceFlush() async {
    // Drain the entire queue
    while (_queue.isNotEmpty) {
      await _exportBatch();
    }
    await exporter.forceFlush();
  }

  void _startTimer() {
    _timer = Timer.periodic(scheduledDelayMillis, (_) {
      if (!_shutdown && _queue.isNotEmpty) {
        _exportBatch();
      }
    });
  }

  Future<void> _exportBatch() async {
    if (_queue.isEmpty) return;

    final batch = _queue.take(maxExportBatchSize).toList();
    _queue.removeRange(0, batch.length);

    try {
      await exporter.export(batch);
    } catch (e) {
      // Log error but continue processing
      // ignore: avoid_print
      print('Error exporting spans: $e');
    }
  }
}
