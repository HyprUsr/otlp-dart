import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:otlp_dart/otlp_dart.dart';

/// Example demonstrating how to compose multiple HTTP client wrappers.
///
/// This shows how OtlpHttpClient can wrap other custom HTTP clients,
/// allowing you to combine instrumentation with logging, retries, rate limiting, etc.
///
/// Prerequisites:
/// 1. Start .NET Aspire Dashboard:
///    docker run --rm -it -p 18888:18888 -p 18889:18889 \
///      mcr.microsoft.com/dotnet/aspire-dashboard:latest
///
/// 2. Access the dashboard at: http://localhost:18888

/// A simple logging HTTP client that logs all requests
class LoggingHttpClient extends http.BaseClient {

  LoggingHttpClient(http.BaseClient inner) : _inner = inner;
  final http.BaseClient _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    print('[HTTP] ${request.method} ${request.url}');
    final startTime = DateTime.now();

    try {
      final response = await _inner.send(request);
      final duration = DateTime.now().difference(startTime);
      print('[HTTP] ${response.statusCode} - ${duration.inMilliseconds}ms');
      return response;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('[HTTP] ERROR after ${duration.inMilliseconds}ms: $e');
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}

/// A simple retry HTTP client
class RetryHttpClient extends http.BaseClient {

  RetryHttpClient(
    http.BaseClient inner, {
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 500),
  }) : _inner = inner;
  final http.BaseClient _inner;
  final int maxRetries;
  final Duration retryDelay;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var attempts = 0;
    while (true) {
      attempts++;
      try {
        return await _inner.send(request);
      } catch (e) {
        if (attempts >= maxRetries) {
          rethrow;
        }
        print('[RETRY] Attempt $attempts failed, retrying in ${retryDelay.inMilliseconds}ms...');
        await Future.delayed(retryDelay);
      }
    }
  }

  @override
  void close() => _inner.close();
}

/// A custom header injection client
class HeaderInjectionHttpClient extends http.BaseClient {

  HeaderInjectionHttpClient(
    http.BaseClient inner, {
    required this.headers,
  }) : _inner = inner;
  final http.BaseClient _inner;
  final Map<String, String> headers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Clone the request with additional headers
    final newRequest = _cloneRequest(request);
    headers.forEach((key, value) {
      newRequest.headers[key] = value;
    });
    return _inner.send(newRequest);
  }

  http.BaseRequest _cloneRequest(http.BaseRequest request) {
    http.BaseRequest newRequest;

    if (request is http.Request) {
      newRequest = http.Request(request.method, request.url)
        ..bodyBytes = request.bodyBytes
        ..encoding = request.encoding;
    } else if (request is http.MultipartRequest) {
      newRequest = http.MultipartRequest(request.method, request.url)
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);
    } else if (request is http.StreamedRequest) {
      throw UnsupportedError('Cannot clone a StreamedRequest');
    } else {
      throw UnsupportedError('Unknown request type');
    }

    newRequest.headers.addAll(request.headers);
    newRequest.persistentConnection = request.persistentConnection;
    newRequest.followRedirects = request.followRedirects;
    newRequest.maxRedirects = request.maxRedirects;

    return newRequest;
  }

  @override
  void close() => _inner.close();
}

void main() async {
  // Create a resource identifying your service
  final resource = Resource.create(
    serviceName: 'composable-http-demo',
    serviceVersion: '1.0.0',
    serviceInstanceId: 'instance-1',
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
      scheduledDelayMillis: const Duration(seconds: 2),
    ),
  );

  final tracer = tracerProvider.getTracer('composable-http-demo', version: '1.0.0');

  print('Composable HTTP Client Demo');
  print('=============================\n');

  // Example 1: Simple instrumented client
  print('Example 1: Basic Instrumented Client');
  print('-------------------------------------');
  final basicClient = OtlpHttpClient(tracer);

  final response1 = await basicClient.get(
    Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
  );
  print('Response: ${response1.statusCode}\n');
  basicClient.close();

  // Example 2: Instrumented + Logging
  print('Example 2: Instrumented + Logging');
  print('----------------------------------');
  final loggingClient = LoggingHttpClient(
    http.Client() as http.BaseClient,
  );
  final instrumentedLoggingClient = OtlpHttpClient(
    tracer,
    inner: loggingClient,
  );

  final response2 = await instrumentedLoggingClient.get(
    Uri.parse('https://jsonplaceholder.typicode.com/posts/2'),
  );
  print('Response: ${response2.statusCode}\n');
  instrumentedLoggingClient.close();

  // Example 3: Full Stack - Instrumented + Retry + Logging + Headers
  print('Example 3: Full Stack (Instrumented + Retry + Logging + Headers)');
  print('----------------------------------------------------------------');

  // Build the stack from inside out:
  // 1. Start with base client
  final baseClient = http.Client() as http.BaseClient;

  // 2. Add logging
  final withLogging = LoggingHttpClient(baseClient);

  // 3. Add retry logic
  final withRetry = RetryHttpClient(withLogging, maxRetries: 2);

  // 4. Add custom headers
  final withHeaders = HeaderInjectionHttpClient(
    withRetry,
    headers: {
      'X-Custom-Header': 'my-app-v1.0',
      'X-Request-ID': DateTime.now().millisecondsSinceEpoch.toString(),
    },
  );

  // 5. Add OpenTelemetry instrumentation (outermost layer)
  final fullStackClient = OtlpHttpClient(
    tracer,
    inner: withHeaders,
  );

  print('Making request with full stack...');
  final response3 = await fullStackClient.get(
    Uri.parse('https://jsonplaceholder.typicode.com/posts/3'),
  );
  print('Response: ${response3.statusCode}\n');

  // Example 4: Test retry behavior with an invalid host
  print('Example 4: Testing Retry Behavior');
  print('----------------------------------');
  print('Attempting request to invalid host (will retry 2 times)...');
  try {
    await fullStackClient.get(
      Uri.parse('https://this-will-definitely-fail-12345.com/api'),
    );
  } catch (e) {
    print('Expected failure after retries: ${e.runtimeType}\n');
  }

  fullStackClient.close();

  // Flush telemetry
  print('Flushing telemetry to Aspire Dashboard...');
  await tracerProvider.forceFlush();
  await Future.delayed(const Duration(seconds: 1));
  await tracerProvider.shutdown();

  print('\n✓ Done! Check the Aspire Dashboard at http://localhost:18888');
  print('\nKey Takeaways:');
  print('- OtlpHttpClient accepts any http.BaseClient as inner client');
  print('- You can compose multiple client wrappers for different behaviors');
  print('- The order matters: outer clients wrap inner clients');
  print('- All requests flow through the full stack of wrappers');
  print('- Each layer adds its own functionality (logging, retries, headers, tracing)');
}
