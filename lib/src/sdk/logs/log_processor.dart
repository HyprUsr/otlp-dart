import 'dart:async';
import '../../api/logs/log_record.dart';
import 'log_exporter.dart';

/// LogRecordProcessor handles log record lifecycle events.
abstract class LogRecordProcessor {
  /// Called when a log record is emitted.
  void onEmit(LogRecord logRecord);

  /// Exports all pending log records and shuts down the processor.
  Future<void> shutdown();

  /// Exports all pending log records.
  Future<void> forceFlush();
}

/// SimpleLogRecordProcessor exports log records immediately.
class SimpleLogRecordProcessor implements LogRecordProcessor {

  SimpleLogRecordProcessor(this.exporter);
  final LogRecordExporter exporter;

  @override
  void onEmit(LogRecord logRecord) {
    exporter.export([logRecord]);
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

/// BatchLogRecordProcessor batches log records and exports them periodically.
class BatchLogRecordProcessor implements LogRecordProcessor {

  BatchLogRecordProcessor({
    required this.exporter,
    this.maxQueueSize = 2048,
    this.maxExportBatchSize = 512,
    this.scheduledDelayMillis = const Duration(milliseconds: 5000),
  }) {
    _startTimer();
  }
  final LogRecordExporter exporter;
  final int maxQueueSize;
  final int maxExportBatchSize;
  final Duration scheduledDelayMillis;

  final List<LogRecord> _queue = [];
  Timer? _timer;
  bool _shutdown = false;

  @override
  void onEmit(LogRecord logRecord) {
    if (_shutdown) return;

    if (_queue.length >= maxQueueSize) {
      return;
    }

    _queue.add(logRecord);

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
      // ignore: avoid_print
      print('Error exporting log records: $e');
    }
  }
}
