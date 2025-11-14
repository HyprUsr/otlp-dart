import 'dart:async';
import 'dart:math';
import 'package:otlp_dart/otlp_dart.dart';

/// Comprehensive example demonstrating all OTLP Dart features.
///
/// This example demonstrates:
/// - Traces: Distributed tracing with spans, nested spans, and span links
/// - Logs: Structured logging at all severity levels
/// - Metrics: Counters and histograms for tracking measurements
/// - HTTP Client Instrumentation: Automatic tracing of HTTP requests
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
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║        OTLP Dart - Comprehensive Telemetry Example           ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');
  print('Sending telemetry to Aspire Dashboard...');
  print('View dashboard at: http://localhost:18888');
  print('');

  // ========================================================================
  // SETUP: Create Resource and Providers
  // ========================================================================
  print('⚙️  Setting up telemetry providers...');

  // Create a resource identifying your service
  final resource = Resource.create(
    serviceName: 'otlp-dart-demo',
    serviceVersion: '1.0.0',
    serviceInstanceId: 'demo-instance-1',
    additionalAttributes: {
      'deployment.environment': 'development',
      'host.name': 'local-machine',
    },
  );

  // Configure exporters for Aspire Dashboard
  final traceExporter = OtlpHttpTraceExporter.aspire(
    host: 'localhost',
    port: 18889,
  );

  final logExporter = OtlpHttpLogExporter.aspire(
    host: 'localhost',
    port: 18889,
  );

  final metricExporter = OtlpHttpMetricExporter.aspire(
    host: 'localhost',
    port: 18889,
  );

  // Create providers
  final tracerProvider = TracerProviderImpl(
    resource: resource,
    processor: BatchSpanProcessor(
      exporter: traceExporter,
      maxExportBatchSize: 512,
      scheduledDelayMillis: const Duration(seconds: 5),
    ),
  );

  final loggerProvider = LoggerProviderImpl(
    resource: resource,
    processor: BatchLogRecordProcessor(
      exporter: logExporter,
      maxExportBatchSize: 512,
      scheduledDelayMillis: const Duration(seconds: 5),
    ),
  );

  final metricReader = PeriodicMetricReader(
    exporter: metricExporter,
    resource: resource,
    scope: InstrumentationScope(
      name: 'otlp-dart-demo',
      version: '1.0.0',
    ),
    interval: const Duration(seconds: 10),
  );

  final meterProvider = MeterProviderImpl(
    resource: resource,
    reader: metricReader,
  );

  // Get instruments
  final tracer = tracerProvider.getTracer('otlp-dart-demo', version: '1.0.0');
  final logger = loggerProvider.getLogger('otlp-dart-demo', version: '1.0.0');
  final meter = meterProvider.getMeter('otlp-dart-demo', version: '1.0.0');

  print('✓ Telemetry providers initialized');
  print('');

  // ========================================================================
  // SECTION 1: Traces & Logs - Business Operation
  // ========================================================================
  print('🔍 Section 1: Traces & Logs - Processing Orders');
  print('─────────────────────────────────────────────────────────────');

  await tracer.withSpanAsync(
    'process-order',
    (span) async {
      span.setAttribute('order.id', AttributeValue.string('ORD-12345'));
      span.setAttribute('order.amount', AttributeValue.double(249.99));
      span.setAttribute('order.items', AttributeValue.int(3));

      logger.info('Processing order', attributes: {
        'order.id': AttributeValue.string('ORD-12345'),
        'customer.id': AttributeValue.string('CUST-789'),
      },);

      print('  📦 Processing order ORD-12345 (\$249.99, 3 items)');

      // Simulate validation
      await Future.delayed(const Duration(milliseconds: 100));

      // Nested span: Validate payment
      await tracer.withSpanAsync(
        'validate-payment',
        (paymentSpan) async {
          paymentSpan.setAttribute(
              'payment.method', AttributeValue.string('credit-card'),);
          paymentSpan.setAttribute('payment.amount', AttributeValue.double(249.99));

          logger.debug('Validating payment method');

          await Future.delayed(const Duration(milliseconds: 50));

          paymentSpan.setStatus(const SpanStatus.ok());
          print('  ✓ Payment validated');
        },
        kind: SpanKind.internal,
        parent: span,
      );

      // Nested span: Update inventory
      await tracer.withSpanAsync(
        'update-inventory',
        (inventorySpan) async {
          inventorySpan.setAttribute('items.reserved', AttributeValue.int(3));

          logger.debug('Updating inventory');

          await Future.delayed(const Duration(milliseconds: 75));

          inventorySpan.addEvent('inventory-updated', attributes: {
            'items.remaining': AttributeValue.int(47),
          },);

          print('  ✓ Inventory updated');
        },
        kind: SpanKind.internal,
        parent: span,
      );

      // Nested span: Send confirmation
      await tracer.withSpanAsync(
        'send-confirmation',
        (confirmSpan) async {
          confirmSpan.setAttribute('email', AttributeValue.string('[email protected]'));

          logger.info('Sending order confirmation email');

          await Future.delayed(const Duration(milliseconds: 30));

          print('  ✓ Confirmation email sent');
        },
        kind: SpanKind.client,
        parent: span,
      );

      span.setStatus(const SpanStatus.ok());
      logger.info('Order processed successfully');
    },
    kind: SpanKind.server,
  );

  print('');

  // ========================================================================
  // SECTION 2: HTTP Client Instrumentation
  // ========================================================================
  print('🌐 Section 2: HTTP Client Instrumentation');
  print('─────────────────────────────────────────────────────────────');

  final httpClient = OtlpHttpClient(
    tracer,
    captureHeaders: true,
    captureRequestBody: false,
    captureResponseBody: false,
  );

  try {
    // Make instrumented HTTP requests
    await tracer.withSpanAsync(
      'fetch-user-data',
      (parentSpan) async {
        parentSpan.setAttribute('operation', AttributeValue.string('data-sync'));

        logger.info('Fetching user data from API');

        // Fetch user
        print('  🔗 GET /users/1');
        final userResponse = await httpClient.get(
          Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
        );

        parentSpan.addEvent('user-fetched', attributes: {
          'status': AttributeValue.int(userResponse.statusCode),
        },);

        // Fetch posts
        print('  🔗 GET /users/1/posts');
        final postsResponse = await httpClient.get(
          Uri.parse('https://jsonplaceholder.typicode.com/users/1/posts'),
        );

        parentSpan.addEvent('posts-fetched', attributes: {
          'status': AttributeValue.int(postsResponse.statusCode),
          'count': AttributeValue.int(10), // Simulated
        },);

        print('  ✓ Fetched user data from 2 API endpoints');

        parentSpan.setAttribute('api.calls', AttributeValue.int(2));
        parentSpan.setStatus(const SpanStatus.ok());

        logger.info('User data fetched successfully');
      },
      kind: SpanKind.internal,
    );
  } finally {
    httpClient.close();
  }

  print('');

  // ========================================================================
  // SECTION 3: Error Handling & Logging
  // ========================================================================
  print('⚠️  Section 3: Error Handling & Logging');
  print('─────────────────────────────────────────────────────────────');

  try {
    await tracer.withSpanAsync(
      'risky-operation',
      (span) async {
        span.setAttribute('operation.type', AttributeValue.string('database'));

        logger.warn('Attempting potentially risky operation');

        await Future.delayed(const Duration(milliseconds: 50));

        print('  ⚠️  Simulating database error...');
        throw Exception('Database connection timeout');
      },
      kind: SpanKind.client,
    );
  } catch (e) {
    logger.error('Operation failed: $e');
    print('  ✓ Error logged and traced');
  }

  // Demonstrate all log levels
  print('  📝 Logging at all severity levels...');
  logger.trace('This is a trace-level message');
  logger.debug('This is a debug-level message');
  logger.info('This is an info-level message');
  logger.warn('This is a warning-level message');
  logger.error('This is an error-level message');
  logger.fatal('This is a fatal-level message');
  print('  ✓ All log levels demonstrated');

  print('');

  // ========================================================================
  // SECTION 4: Metrics - HTTP Request Simulation
  // ========================================================================
  print('📈 Section 4: Metrics - HTTP Request Tracking');
  print('─────────────────────────────────────────────────────────────');

  final requestCounter = meter.createCounter(
    'http.server.requests',
    unit: 'requests',
    description: 'Total number of HTTP requests',
  );

  final requestDuration = meter.createHistogram(
    'http.server.duration',
    unit: 'ms',
    description: 'HTTP request duration in milliseconds',
  );

  final random = Random();
  final endpoints = ['/api/users', '/api/products', '/api/orders'];
  final methods = ['GET', 'POST', 'PUT', 'DELETE'];
  final statusCodes = [200, 201, 400, 404, 500];

  print('  🎲 Simulating 15 HTTP requests...');

  for (var i = 0; i < 15; i++) {
    final endpoint = endpoints[random.nextInt(endpoints.length)];
    final method = methods[random.nextInt(methods.length)];
    final statusCode = statusCodes[random.nextInt(statusCodes.length)];
    final duration = 50 + random.nextDouble() * 450;

    // Record metrics
    requestCounter.add(
      1,
      attributes: {
        'http.method': AttributeValue.string(method),
        'http.route': AttributeValue.string(endpoint),
        'http.status_code': AttributeValue.int(statusCode),
      },
    );

    requestDuration.record(
      duration,
      attributes: {
        'http.method': AttributeValue.string(method),
        'http.route': AttributeValue.string(endpoint),
        'http.status_code': AttributeValue.int(statusCode),
      },
    );

    if (i < 3) {
      // Only print first few to keep output clean
      print(
          '    $method $endpoint -> $statusCode (${duration.toStringAsFixed(1)}ms)',);
    }

    await Future.delayed(const Duration(milliseconds: 50));
  }

  print('    ... (12 more requests)');
  print('  ✓ Recorded 15 HTTP requests with timing data');
  print('');

  // ========================================================================
  // SECTION 5: Distributed Tracing with Span Links
  // ========================================================================
  print('🔗 Section 5: Distributed Tracing - Span Links');
  print('─────────────────────────────────────────────────────────────');

  // Create first operation
  final span1 = tracer.startSpan('async-job-enqueue', kind: SpanKind.producer);
  span1.setAttribute('job.id', AttributeValue.string('JOB-001'));
  span1.setAttribute('job.type', AttributeValue.string('email-batch'));
  await Future.delayed(const Duration(milliseconds: 50));
  span1.end();

  print('  ✓ Job enqueued: JOB-001');

  // Link to the previous span from a new trace (simulating async processing)
  await Future.delayed(const Duration(milliseconds: 100));

  final span2 = tracer.startSpan(
    'async-job-process',
    kind: SpanKind.consumer,
    links: [
      SpanLink(context: span1.context),
    ],
  );
  span2.setAttribute('job.id', AttributeValue.string('JOB-001'));
  span2.setAttribute('worker.id', AttributeValue.string('WORKER-3'));
  await Future.delayed(const Duration(milliseconds: 150));
  span2.end();

  logger.info('Async job processed', attributes: {
    'job.id': AttributeValue.string('JOB-001'),
  },);

  print('  ✓ Job processed by worker: WORKER-3');
  print('  ✓ Span link created (distributed trace)');
  print('');

  // ========================================================================
  // SECTION 6: Concurrent Operations
  // ========================================================================
  print('⚡ Section 6: Concurrent Background Tasks');
  print('─────────────────────────────────────────────────────────────');

  final futures = <Future>[];
  for (var i = 0; i < 5; i++) {
    futures.add(
      tracer.withSpanAsync(
        'background-task-$i',
        (span) async {
          span.setAttribute('task.id', AttributeValue.int(i));
          span.setAttribute('task.priority', AttributeValue.string('normal'));

          await Future.delayed(Duration(milliseconds: 50 + i * 10));

          span.addEvent('checkpoint', attributes: {
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
  print('  ✓ Completed 5 concurrent background tasks');
  print('');

  // ========================================================================
  // FLUSH AND SHUTDOWN
  // ========================================================================
  print('💾 Flushing all telemetry to Aspire Dashboard...');

  print('  Flushing traces...');
  await tracerProvider.forceFlush();
  print('  ✓ Traces flushed');

  print('  Flushing logs...');
  await loggerProvider.forceFlush();
  print('  ✓ Logs flushed');

  print('  Flushing metrics...');
  await meterProvider.forceFlush();
  print('  ✓ Metrics flushed');
  print('');

  print('Waiting for background export...');
  await Future.delayed(const Duration(seconds: 2));

  print('Shutting down telemetry providers...');
  await tracerProvider.shutdown();
  await loggerProvider.shutdown();
  await meterProvider.shutdown();

  print('  ✓ Shutdown complete');
  print('');

  // ========================================================================
  // SUMMARY
  // ========================================================================
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║                      🎉 Demo Complete!                        ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');
  print('View your telemetry at: http://localhost:18888');
  print('');
  print('📊 What was demonstrated:');
  print('  ✓ Traces: Nested spans, span links, distributed tracing');
  print('  ✓ Logs: All severity levels with structured attributes');
  print('  ✓ Metrics: Counters and histograms for measurements');
  print('  ✓ HTTP: Automatic instrumentation of HTTP requests');
  print('  ✓ Errors: Exception recording and error traces');
  print('  ✓ Async: Concurrent operations and background tasks');
  print('');
  print('📑 Check these tabs in Aspire Dashboard:');
  print('  • Traces tab - View all spans and distributed traces');
  print('  • Structured tab - Browse logs with filtering');
  print('  • Metrics tab - Analyze counters and histograms');
  print('');
}
