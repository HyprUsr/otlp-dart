import 'package:test/test.dart';
import 'package:otlp_dart/otlp_dart.dart';
import 'package:otlp_dart/src/sdk/logs/log_exporter.dart';

class TestLogExporter implements LogRecordExporter {
  final List<LogRecord> exportedLogs = [];

  @override
  Future<void> export(List<LogRecord> logRecords) async {
    exportedLogs.addAll(logRecords);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

void main() {
  group('Logger', () {
    late Resource resource;
    late TestLogExporter exporter;
    late LoggerProviderImpl loggerProvider;
    late Logger logger;

    setUp(() {
      resource = Resource.create(serviceName: 'test-service');
      exporter = TestLogExporter();
      loggerProvider = LoggerProviderImpl(
        resource: resource,
        processor: SimpleLogRecordProcessor(exporter),
      );
      logger = loggerProvider.getLogger('test');
    });

    tearDown(() async {
      await loggerProvider.shutdown();
    });

    test('emits log at different severity levels', () {
      logger.trace('trace message');
      logger.debug('debug message');
      logger.info('info message');
      logger.warn('warn message');
      logger.error('error message');
      logger.fatal('fatal message');

      expect(exporter.exportedLogs.length, equals(6));
      expect(exporter.exportedLogs[0].severity, equals(Severity.trace));
      expect(exporter.exportedLogs[1].severity, equals(Severity.debug));
      expect(exporter.exportedLogs[2].severity, equals(Severity.info));
      expect(exporter.exportedLogs[3].severity, equals(Severity.warn));
      expect(exporter.exportedLogs[4].severity, equals(Severity.error));
      expect(exporter.exportedLogs[5].severity, equals(Severity.fatal));
    });

    test('logs with attributes', () {
      logger.info('test message', attributes: {
        'key': AttributeValue.string('value'),
        'number': AttributeValue.int(42),
      },);

      expect(exporter.exportedLogs.length, equals(1));
      final log = exporter.exportedLogs.first;
      expect(log.body, equals('test message'));
      expect(log.attributes.length, equals(2));
    });

    test('logs with trace context', () {
      logger.log(
        Severity.info,
        'correlated log',
        traceId: 'trace123',
        spanId: 'span456',
      );

      final log = exporter.exportedLogs.first;
      expect(log.traceId, equals('trace123'));
      expect(log.spanId, equals('span456'));
    });

    test('log has correct timestamps', () {
      logger.info('test');

      final log = exporter.exportedLogs.first;
      expect(log.timeUnixNano, greaterThan(0));
      expect(log.observedTimeUnixNano, greaterThan(0));
    });

    test('log record has resource', () {
      logger.info('test');

      final log = exporter.exportedLogs.first;
      expect(log.resource, isNotNull);
      expect(log.resource, equals(resource));
    });

    test('log record serializes to JSON', () {
      logger.info('test message');

      final log = exporter.exportedLogs.first;
      final json = log.toJson();

      expect(json['body']['stringValue'], equals('test message'));
      expect(json['severityNumber'], equals(Severity.info.value));
      expect(json['severityText'], equals('INFO'));
    });
  });

  group('Severity', () {
    test('has correct text values', () {
      expect(Severity.trace.text, equals('TRACE'));
      expect(Severity.debug.text, equals('DEBUG'));
      expect(Severity.info.text, equals('INFO'));
      expect(Severity.warn.text, equals('WARN'));
      expect(Severity.error.text, equals('ERROR'));
      expect(Severity.fatal.text, equals('FATAL'));
    });

    test('has correct numeric values', () {
      expect(Severity.trace.value, equals(1));
      expect(Severity.debug.value, equals(5));
      expect(Severity.info.value, equals(9));
      expect(Severity.warn.value, equals(13));
      expect(Severity.error.value, equals(17));
      expect(Severity.fatal.value, equals(21));
    });
  });
}
