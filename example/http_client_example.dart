import 'package:otlp_dart/otlp_dart.dart';
import 'package:otlp_dart/src/sdk/trace/tracer_provider_impl.dart';
import 'package:otlp_dart/src/sdk/trace/span_processor.dart';

/// Example demonstrating HTTP client instrumentation with OpenTelemetry.
///
/// This example shows how to use InstrumentedHttpClient to automatically
/// capture trace information for HTTP requests, similar to how ASP.NET Core
/// Kestrel reports to Aspire Dashboard.
///
/// Prerequisites:
/// 1. Start .NET Aspire Dashboard:
///    docker run --rm -it -p 18888:18888 -p 18889:18889 \
///      mcr.microsoft.com/dotnet/aspire-dashboard:latest
///
/// 2. Access the dashboard at: http://localhost:18888
///
/// The dashboard will display HTTP client requests with:
/// - Request method, URL, headers
/// - Response status code, headers
/// - Request/response timing
/// - Any errors that occurred
void main() async {
  // Create a resource identifying your service
  final resource = Resource.create(
    serviceName: 'http-client-demo',
    serviceVersion: '1.0.0',
    serviceInstanceId: 'instance-1',
    additionalAttributes: {
      'deployment.environment': 'development',
    },
  );

  // Configure trace exporter for Aspire Dashboard
  final traceExporter = OtlpHttpTraceExporter.aspire(
    host: 'localhost',
    port: 18889,
  );

  // Create tracer provider
  final tracerProvider = TracerProviderImpl(
    resource: resource,
    processor: BatchSpanProcessor(
      exporter: traceExporter,
      maxExportBatchSize: 512,
      scheduledDelayMillis: Duration(seconds: 2),
    ),
  );

  // Get a tracer
  final tracer = tracerProvider.getTracer('http-client-demo', version: '1.0.0');

  print('HTTP Client Instrumentation Demo');
  print('Sending requests to Aspire Dashboard...');
  print('View dashboard at: http://localhost:18888');
  print('');

  // Create instrumented HTTP client
  final client = OtlpHttpClient(
    tracer,
    captureHeaders: true,
    captureRequestBody: false,
    captureResponseBody: false,
  );

  try {
    // Example 1: Successful GET request
    print('Example 1: Making GET request to JSONPlaceholder API...');
    await tracer.withSpanAsync(
      'fetch-users',
      (parentSpan) async {
        parentSpan.setAttribute(
          'operation.type',
          AttributeValue.string('data-fetch'),
        );

        final response = await client.get(
          Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
        );

        parentSpan.addEvent('response-received', attributes: {
          'status': AttributeValue.int(response.statusCode),
          'body_length': AttributeValue.int(response.body.length),
        });

        print('  ✓ Status: ${response.statusCode}');
        print('  ✓ User: ${response.body.substring(0, 50)}...');
      },
      kind: SpanKind.internal,
    );

    // Example 2: Multiple concurrent requests
    print('\nExample 2: Making concurrent requests...');
    await tracer.withSpanAsync(
      'fetch-multiple-posts',
      (parentSpan) async {
        final futures = <Future>[];
        for (var i = 1; i <= 3; i++) {
          futures.add(
            client.get(
              Uri.parse('https://jsonplaceholder.typicode.com/posts/$i'),
            ),
          );
        }

        final responses = await Future.wait(futures);
        print('  ✓ Fetched ${responses.length} posts');

        parentSpan.setAttribute(
          'posts.count',
          AttributeValue.int(responses.length),
        );
      },
      kind: SpanKind.internal,
    );

    // Example 3: POST request with body
    print('\nExample 3: Making POST request...');
    await tracer.withSpanAsync(
      'create-post',
      (parentSpan) async {
        final response = await client.post(
          Uri.parse('https://jsonplaceholder.typicode.com/posts'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: '{"title": "Test Post", "body": "This is a test", "userId": 1}',
        );

        print('  ✓ Created post, status: ${response.statusCode}');

        parentSpan.setAttribute(
          'post.created',
          AttributeValue.bool(response.statusCode == 201),
        );
      },
      kind: SpanKind.internal,
    );

    // Example 4: Request that returns 404
    print('\nExample 4: Making request that returns 404...');
    await tracer.withSpanAsync(
      'fetch-nonexistent',
      (parentSpan) async {
        final response = await client.get(
          Uri.parse('https://jsonplaceholder.typicode.com/posts/99999'),
        );

        print('  ✓ Status: ${response.statusCode} (expected 404)');

        if (response.statusCode == 404) {
          parentSpan.addEvent('resource-not-found');
        }
      },
      kind: SpanKind.internal,
    );

    // Example 5: Simulated error handling
    print('\nExample 5: Handling connection errors...');
    try {
      await tracer.withSpanAsync(
        'fetch-invalid-host',
        (parentSpan) async {
          // This will fail with a network error
          await client.get(
            Uri.parse('https://this-host-does-not-exist-12345.com/api'),
          );
        },
        kind: SpanKind.internal,
      );
    } catch (e) {
      print('  ✓ Caught expected error: ${e.runtimeType}');
    }

    // Example 6: Nested HTTP calls (service calling another service)
    print('\nExample 6: Nested service calls...');
    await tracer.withSpanAsync(
      'process-user-data',
      (parentSpan) async {
        // First, fetch the user
        final userResponse = await client.get(
          Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
        );

        parentSpan.addEvent('user-fetched');

        // Then, fetch their posts
        final postsResponse = await client.get(
          Uri.parse('https://jsonplaceholder.typicode.com/users/1/posts'),
        );

        parentSpan.addEvent('posts-fetched');

        // Finally, fetch their todos
        final todosResponse = await client.get(
          Uri.parse('https://jsonplaceholder.typicode.com/users/1/todos'),
        );

        parentSpan.addEvent('todos-fetched');

        print('  ✓ Fetched user data from 3 endpoints');

        parentSpan.setAttribute(
          'user.endpoints_called',
          AttributeValue.int(3),
        );
      },
      kind: SpanKind.internal,
    );

    print('\n✓ All examples completed successfully!');
  } finally {
    client.close();
  }

  // Flush all telemetry
  print('\nFlushing telemetry to Aspire Dashboard...');
  await tracerProvider.forceFlush();
  print('✓ Telemetry flushed');

  // Cleanup
  await Future.delayed(Duration(seconds: 1));
  await tracerProvider.shutdown();

  print('\nDone! Check the Aspire Dashboard at http://localhost:18888');
  print('- View HTTP traces in the "Traces" tab');
  print('- Each HTTP request is automatically instrumented with:');
  print('  • Request method and URL');
  print('  • Request/response headers');
  print('  • HTTP status codes');
  print('  • Timing information');
  print('  • Error details (if any)');
}
