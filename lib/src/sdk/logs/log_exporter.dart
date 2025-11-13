import '../../api/logs/log_record.dart';

/// LogRecordExporter exports log records to a backend.
abstract class LogRecordExporter {
  /// Exports a batch of log records.
  Future<void> export(List<LogRecord> logRecords);

  /// Ensures all pending exports are completed.
  Future<void> forceFlush();

  /// Shuts down the exporter.
  Future<void> shutdown();
}
