import 'package:otlp_dart/otlp_dart.dart';

/// Example demonstrating how to use otlp_dart with .NET Aspire Dashboard.
///
/// Prerequisites:
/// 1. Start .NET Aspire Dashboard:
///    docker run --rm -it -p 18888:18888 -p 18889:18889 \
///      mcr.microsoft.com/dotnet/aspire-dashboard:latest
///
/// 2. Access the dashboard at: http://localhost:18888
///
/// The dashboard will display:
/// - Traces on the "Traces" tab
/// - Logs on the "Structured" tab
/// - Metrics on the "Metrics" tab
void main() async {
  // Create a resource identifying your service
  final resource = Resource.create(
    serviceName: 'my-dart-app',
    serviceVersion: '1.0.0',
    serviceInstanceId: 'instance-1',
    additionalAttributes: {
      'environment': 'development',
      'host.name': 'my-machine',
    },
  );

  // Configure trace exporter for Aspire Dashboard
  final traceExporter = OtlpHttpTraceExporter.aspire(
    host: 'localhost',
    port: 18889,
  );

  // Create tracer provider with batch processing
  final tracerProvider = TracerProviderImpl(
    resource: resource,
    processor: BatchSpanProcessor(
      exporter: traceExporter,
      maxExportBatchSize: 512,
      scheduledDelayMillis: const Duration(seconds: 5),
    ),
  );

  // Configure log exporter for Aspire Dashboard
  final logExporter = OtlpHttpLogExporter.aspire(
    host: 'localhost',
    port: 18889,
  );

  // Create logger provider with batch processing
  final loggerProvider = LoggerProviderImpl(
    resource: resource,
    processor: BatchLogRecordProcessor(
      exporter: logExporter,
      maxExportBatchSize: 512,
      scheduledDelayMillis: const Duration(seconds: 5),
    ),
  );

  // Get a tracer and logger
  final tracer = tracerProvider.getTracer('my-dart-app', version: '1.0.0');
  final logger = loggerProvider.getLogger('my-dart-app', version: '1.0.0');

  print('Sending telemetry to Aspire Dashboard...');
  print('View dashboard at: http://localhost:18888');
  print('');

  // Example 1: Simple span with automatic cleanup
  await tracer.withSpanAsync(
    'process-order',
    (span) async {
      span.setAttribute('order.id', AttributeValue.string('12345'));
      span.setAttribute('order.amount', AttributeValue.double(99.99));

      logger.info('Processing order 12345', attributes: {
        'order.id': AttributeValue.string('12345'),
      },);

      // Simulate some work
      await Future.delayed(const Duration(milliseconds: 100));

      // Create nested span
      await tracer.withSpanAsync(
        'validate-payment',
        (paymentSpan) async {
          paymentSpan.setAttribute(
              'payment.method', AttributeValue.string('credit-card'),);

          logger.debug('Validating payment');

          await Future.delayed(const Duration(milliseconds: 50));

          paymentSpan.setStatus(const SpanStatus.ok());
        },
        kind: SpanKind.internal,
        parent: span,
      );

      // Another nested span
      await tracer.withSpanAsync(
        'send-confirmation',
        (confirmSpan) async {
          confirmSpan.setAttribute('email', AttributeValue.string('[email protected]'));

          logger.info('Sending confirmation email');

          await Future.delayed(const Duration(milliseconds: 30));
        },
        kind: SpanKind.client,
        parent: span,
      );

      span.setStatus(const SpanStatus.ok());
    },
    kind: SpanKind.server,
  );

  print('✓ Sent order processing trace with nested spans');

  // Example 2: Error handling with exception recording
  try {
    await tracer.withSpanAsync(
      'failing-operation',
      (span) async {
        span.setAttribute('operation.type', AttributeValue.string('database'));

        logger.warn('Attempting risky operation');

        await Future.delayed(const Duration(milliseconds: 20));

        throw Exception('Database connection failed');
      },
      kind: SpanKind.client,
    );
  } catch (e) {
    logger.error('Operation failed: $e');
  }

  print('✓ Sent error trace with exception details');

  // Example 3: Multiple independent operations
  final futures = <Future>[];
  for (var i = 0; i < 5; i++) {
    futures.add(
      tracer.withSpanAsync(
        'background-task-$i',
        (span) async {
          span.setAttribute('task.id', AttributeValue.int(i));

          logger.info('Running background task $i', attributes: {
            'task.id': AttributeValue.int(i),
          },);

          await Future.delayed(Duration(milliseconds: 50 + i * 10));

          span.addEvent('task-checkpoint', attributes: {
            'progress': AttributeValue.double(0.5),
          },);

          await Future.delayed(const Duration(milliseconds: 50));

          span.setStatus(const SpanStatus.ok());
        },
        kind: SpanKind.internal,
      ),
    );
  }

  await Future.wait(futures);
  print('✓ Sent 5 concurrent background task traces');

  // Example 4: Different log levels
  logger.trace('This is a trace message');
  logger.debug('This is a debug message');
  logger.info('This is an info message');
  logger.warn('This is a warning message');
  logger.error('This is an error message');
  logger.fatal('This is a fatal message');

  print('✓ Sent logs at all severity levels');

  // Example 5: Span with links (distributed tracing)
  final span1 = tracer.startSpan('operation-1', kind: SpanKind.client);
  span1.setAttribute('operation', AttributeValue.string('fetch-data'));
  await Future.delayed(const Duration(milliseconds: 50));
  span1.end();

  // Link to the previous span from a new trace
  final span2 = tracer.startSpan(
    'operation-2',
    kind: SpanKind.server,
    links: [
      SpanLink(context: span1.context),
    ],
  );
  span2.setAttribute('operation', AttributeValue.string('process-data'));
  await Future.delayed(const Duration(milliseconds: 50));
  span2.end();

  print('✓ Sent linked spans (distributed trace)');

  print('');
  print('Flushing all telemetry...');

  // Force flush to ensure all data is sent
  await tracerProvider.forceFlush();
  await loggerProvider.forceFlush();

  print('✓ All telemetry flushed successfully');

  // Cleanup
  await Future.delayed(const Duration(seconds: 1));
  await tracerProvider.shutdown();
  await loggerProvider.shutdown();

  print('');
  print('Done! Check the Aspire Dashboard at http://localhost:18888');
  print('- View traces in the "Traces" tab');
  print('- View logs in the "Structured" tab');
}
