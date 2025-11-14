# otlp_dart

OpenTelemetry Protocol (OTLP) client library for Dart. Export traces, metrics, and logs to OTLP-compatible backends like .NET Aspire Dashboard, Jaeger, Prometheus, and more.

## Features

- ✅ **OTLP/HTTP support** - Send telemetry via HTTP with JSON encoding
- ✅ **OTLP/HTTP2 with Protobuf** - High-performance binary encoding for Aspire
- ✅ **Distributed Tracing** - Create spans, nested spans, and distributed traces
- ✅ **Structured Logging** - Emit structured logs with attributes
- ✅ **Comprehensive Metrics** - Full SDK with all instrument types
  - Counter (monotonically increasing)
  - UpDownCounter (can increase or decrease)
  - Histogram (value distributions with buckets)
  - ObservableGauge (callback-based current values)
  - ObservableCounter (callback-based cumulative values)
- ✅ **Batch Processing** - Efficient batch export with configurable timing
- ✅ **Resource Attributes** - Identify your service with rich metadata
- ✅ **.NET Aspire Dashboard** - First-class support for Aspire
- ✅ **Automatic Context Propagation** - Parent-child span relationships
- ✅ **Exception Recording** - Automatic exception capture in spans
- ✅ **Delta Temporality** - Efficient metric reporting with automatic reset

## Getting Started

### Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  otlp_dart: ^0.1.0
```

Then run:

```bash
dart pub get
```

### Quick Start with .NET Aspire Dashboard

#### 1. Start the Aspire Dashboard

Using Docker:

```bash
docker run --rm -it -p 18888:18888 -p 18889:18889 \
  mcr.microsoft.com/dotnet/aspire-dashboard:latest
```

Or if you have .NET Aspire installed:

```bash
dotnet run --project YourAspireProject
```

#### 2. Use the Library

```dart
import 'package:otlp_dart/otlp_dart.dart';
import 'package:otlp_dart/src/sdk/trace/tracer_provider_impl.dart';
import 'package:otlp_dart/src/sdk/trace/span_processor.dart';
import 'package:otlp_dart/src/sdk/logs/logger_provider_impl.dart';
import 'package:otlp_dart/src/sdk/logs/log_processor.dart';

void main() async {
  // Create a resource identifying your service
  final resource = Resource.create(
    serviceName: 'my-dart-app',
    serviceVersion: '1.0.0',
  );

  // Setup trace exporter
  final traceExporter = OtlpHttpTraceExporter.aspire(
    host: 'localhost',
    port: 18889,
  );

  final tracerProvider = TracerProviderImpl(
    resource: resource,
    processor: BatchSpanProcessor(exporter: traceExporter),
  );

  // Setup log exporter
  final logExporter = OtlpHttpLogExporter.aspire(
    host: 'localhost',
    port: 18889,
  );

  final loggerProvider = LoggerProviderImpl(
    resource: resource,
    processor: BatchLogRecordProcessor(exporter: logExporter),
  );

  // Get tracer and logger
  final tracer = tracerProvider.getTracer('my-app');
  final logger = loggerProvider.getLogger('my-app');

  // Create traces
  await tracer.withSpanAsync('process-request', (span) async {
    span.setAttribute('user.id', AttributeValue.string('123'));

    logger.info('Processing request');

    // Do some work
    await Future.delayed(Duration(milliseconds: 100));

    span.setStatus(SpanStatus.ok());
  });

  // Cleanup
  await tracerProvider.forceFlush();
  await loggerProvider.forceFlush();
  await tracerProvider.shutdown();
  await loggerProvider.shutdown();
}
```

#### 3. View Your Telemetry

Open the Aspire Dashboard at http://localhost:18888 and explore:
- **Traces** tab - View distributed traces and spans
- **Structured** tab - Browse structured logs
- **Metrics** tab - See metrics and gauges

## Usage Examples

### Tracing

#### Basic Span

```dart
final span = tracer.startSpan('my-operation');
span.setAttribute('key', AttributeValue.string('value'));
// Do work...
span.end();
```

#### Automatic Span Management

```dart
await tracer.withSpanAsync('my-operation', (span) async {
  span.setAttribute('key', AttributeValue.string('value'));
  // Span automatically ends when function completes
  await doWork();
});
```

#### Nested Spans

```dart
await tracer.withSpanAsync('parent-operation', (parentSpan) async {
  parentSpan.setAttribute('type', AttributeValue.string('parent'));

  // Create child span
  await tracer.withSpanAsync(
    'child-operation',
    (childSpan) async {
      childSpan.setAttribute('type', AttributeValue.string('child'));
      await doChildWork();
    },
    parent: parentSpan, // Link to parent
  );
});
```

#### Error Handling

```dart
try {
  await tracer.withSpanAsync('risky-operation', (span) async {
    throw Exception('Something went wrong!');
  });
} catch (e) {
  // Exception is automatically recorded in the span
  print('Error: $e');
}
```

#### Manual Exception Recording

```dart
final span = tracer.startSpan('my-operation');
try {
  throw Exception('Error!');
} catch (e, stackTrace) {
  span.recordException(e, stackTrace: stackTrace);
  span.setStatus(SpanStatus.error('Operation failed'));
} finally {
  span.end();
}
```

#### Span Events

```dart
final span = tracer.startSpan('processing');
span.addEvent('validation-started');
// ... do validation ...
span.addEvent('validation-completed', attributes: {
  'items': AttributeValue.int(42),
});
span.end();
```

#### Span Links (Distributed Tracing)

```dart
// First operation in service A
final span1 = tracer.startSpan('fetch-data');
// ... work ...
span1.end();

// Second operation in service B, linked to first
final span2 = tracer.startSpan(
  'process-data',
  links: [SpanLink(context: span1.context)],
);
span2.end();
```

### Metrics

#### Setting up Metrics

```dart
// Create resource
final resource = Resource(
  attributes: [
    Attribute('service.name', AttributeValue.string('my-service')),
    Attribute('service.version', AttributeValue.string('1.0.0')),
  ],
);

// Create exporter
final exporter = OtlpHttpMetricExporter.aspire(
  host: 'localhost',
  port: 18889,
);

// Create metric reader with periodic export (every 60 seconds)
final reader = PeriodicMetricReader(
  exporter: exporter,
  resource: resource,
  scope: InstrumentationScope(name: 'my-app', version: '1.0.0'),
  interval: const Duration(seconds: 60),
);

// Create meter provider
final meterProvider = MeterProviderImpl(
  resource: resource,
  reader: reader,
);

// Get a meter
final meter = meterProvider.getMeter('my-app');
```

#### Counter - Monotonically Increasing Values

```dart
final requestCounter = meter.createCounter(
  'http.server.requests',
  unit: 'requests',
  description: 'Total number of HTTP requests',
);

// Increment counter with attributes
requestCounter.add(1, attributes: {
  'http.method': AttributeValue.string('GET'),
  'http.route': AttributeValue.string('/api/users'),
  'http.status_code': AttributeValue.int(200),
});
```

#### UpDownCounter - Values That Can Increase or Decrease

```dart
final activeConnections = meter.createUpDownCounter(
  'http.server.active_connections',
  unit: 'connections',
  description: 'Number of active HTTP connections',
);

// Connection opened
activeConnections.add(1);

// Connection closed
activeConnections.add(-1);
```

#### Histogram - Value Distributions

```dart
final requestDuration = meter.createHistogram(
  'http.server.duration',
  unit: 'ms',
  description: 'HTTP request duration',
);

// Record request duration
requestDuration.record(42.5, attributes: {
  'http.method': AttributeValue.string('GET'),
  'http.route': AttributeValue.string('/api/users'),
});

// Histogram automatically calculates:
// - Count of measurements
// - Sum of all values
// - Min and max values
// - Distribution across bucket boundaries
```

#### ObservableGauge - Current Value via Callback

```dart
var memoryUsage = 0.0;

final memoryGauge = meter.createObservableGauge(
  'process.runtime.dart.memory',
  () => memoryUsage,
  unit: 'bytes',
  description: 'Current memory usage',
);

// Update value as needed
memoryUsage = 1024.0 * 1024.0; // 1 MB

// Value is automatically reported during metric collection
```

#### ObservableCounter - Cumulative Value via Callback

```dart
var totalBytes = 0;

final bytesCounter = meter.createObservableCounter(
  'network.bytes.sent',
  () => totalBytes,
  unit: 'bytes',
  description: 'Total bytes sent',
);

// Update cumulative value
totalBytes += 1024;

// Delta is automatically calculated during collection
```

#### Complete Metrics Example

```dart
// Create instruments
final requestCounter = meter.createCounter('http.requests');
final requestDuration = meter.createHistogram('http.duration', unit: 'ms');
final activeConnections = meter.createUpDownCounter('http.connections');

// Simulate HTTP request
activeConnections.add(1); // Connection opened

requestCounter.add(1, attributes: {
  'method': AttributeValue.string('GET'),
  'route': AttributeValue.string('/api/users'),
});

requestDuration.record(156.7, attributes: {
  'method': AttributeValue.string('GET'),
  'route': AttributeValue.string('/api/users'),
});

activeConnections.add(-1); // Connection closed

// Force export
await meterProvider.forceFlush();

// Cleanup
await meterProvider.shutdown();
```

### Logging

#### Basic Logging

```dart
logger.info('Application started');
logger.debug('Debug information');
logger.warn('Warning message');
logger.error('Error occurred');
```

#### Structured Logging with Attributes

```dart
logger.info('User logged in', attributes: {
  'user.id': AttributeValue.string('12345'),
  'user.email': AttributeValue.string('[email protected]'),
  'login.method': AttributeValue.string('oauth'),
});
```

#### Correlated Logs (with Trace Context)

```dart
await tracer.withSpanAsync('operation', (span) async {
  logger.log(
    Severity.info,
    'Operation in progress',
    traceId: span.context.traceId,
    spanId: span.context.spanId,
  );
});
```

### Resource Configuration

Resources identify your service and provide context for all telemetry:

```dart
final resource = Resource.create(
  serviceName: 'my-service',
  serviceVersion: '1.2.3',
  serviceInstanceId: 'pod-123',
  additionalAttributes: {
    'environment': 'production',
    'datacenter': 'us-west-2',
    'host.name': 'server-01',
    'deployment.id': 'v1.2.3-20240101',
  },
);
```

### Batch Processing Configuration

Control how often telemetry is exported:

```dart
final processor = BatchSpanProcessor(
  exporter: traceExporter,
  maxQueueSize: 2048,           // Max spans to queue
  maxExportBatchSize: 512,      // Max spans per batch
  scheduledDelayMillis: Duration(seconds: 5), // Export interval
);
```

### Custom OTLP Endpoint

Use with any OTLP-compatible backend:

```dart
final exporter = OtlpHttpTraceExporter(
  endpoint: 'https://otlp.example.com/v1/traces',
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN',
    'X-Custom-Header': 'value',
  },
  timeout: Duration(seconds: 30),
);
```

## OTLP Backends Compatibility

This library is compatible with any OTLP-compliant backend:

### .NET Aspire Dashboard
- **Default ports**: 18888 (UI), 18889 (OTLP)
- **Use**: `OtlpHttpTraceExporter.aspire()`

### Jaeger
```dart
final exporter = OtlpHttpTraceExporter(
  endpoint: 'http://localhost:4318/v1/traces',
);
```

### Prometheus + OTLP Receiver
```dart
final exporter = OtlpHttpMetricExporter(
  endpoint: 'http://localhost:4318/v1/metrics',
);
```

### Grafana Tempo
```dart
final exporter = OtlpHttpTraceExporter(
  endpoint: 'https://tempo.example.com/v1/traces',
  headers: {'Authorization': 'Basic YOUR_TOKEN'},
);
```

### Grafana Loki
```dart
final exporter = OtlpHttpLogExporter(
  endpoint: 'https://loki.example.com/v1/logs',
  headers: {'Authorization': 'Basic YOUR_TOKEN'},
);
```

### OpenTelemetry Collector
```dart
// Send to OTEL Collector
final exporter = OtlpHttpTraceExporter(
  endpoint: 'http://otel-collector:4318/v1/traces',
);
```

## Architecture

```
┌─────────────────┐
│   Application   │
└────────┬────────┘
         │
         ├─────────► TracerProvider ─► Tracer ─► Span
         │                                         │
         ├─────────► LoggerProvider ─► Logger ─► LogRecord
         │                                         │
         └─────────► MeterProvider ─► Meter ─► Metric
                                                  │
                                                  ▼
                                          SpanProcessor/
                                          LogProcessor
                                                  │
                                                  ▼
                                          Batch Processor
                                                  │
                                                  ▼
                                          OTLP HTTP Exporter
                                                  │
                                                  ▼
                                          Backend (Aspire/Jaeger/etc)
```

## Advanced Topics

### Sampling

Control which spans are recorded:

```dart
// Future enhancement - sampling will be added
```

### Context Propagation

Automatically maintain parent-child relationships:

```dart
// Parent span
await tracer.withSpanAsync('parent', (parent) async {
  // Child automatically inherits parent context
  await tracer.withSpanAsync(
    'child',
    (child) async { /* work */ },
    parent: parent,
  );
});
```

### Span Kinds

Use appropriate span kinds:

```dart
// Server receiving a request
tracer.startSpan('handle-request', kind: SpanKind.server);

// Client making a request
tracer.startSpan('http-call', kind: SpanKind.client);

// Internal operation
tracer.startSpan('compute', kind: SpanKind.internal);

// Message producer
tracer.startSpan('publish', kind: SpanKind.producer);

// Message consumer
tracer.startSpan('consume', kind: SpanKind.consumer);
```

## Best Practices

### 1. Use Resource Attributes

Always identify your service:

```dart
final resource = Resource.create(
  serviceName: 'your-service-name',
  serviceVersion: '1.0.0',
);
```

### 2. Use Semantic Attributes

Follow OpenTelemetry semantic conventions:

```dart
span.setAttribute('http.method', AttributeValue.string('GET'));
span.setAttribute('http.url', AttributeValue.string('https://api.example.com'));
span.setAttribute('http.status_code', AttributeValue.int(200));
```

### 3. Always Flush on Shutdown

```dart
await tracerProvider.forceFlush();
await tracerProvider.shutdown();
```

### 4. Use Batch Processing

For better performance:

```dart
BatchSpanProcessor(exporter: exporter) // ✓ Good
SimpleSpanProcessor(exporter) // ✗ Avoid in production
```

### 5. Handle Errors Gracefully

```dart
try {
  await tracer.withSpanAsync('operation', (span) async {
    await riskyOperation();
  });
} catch (e) {
  // Exception already recorded in span
  logger.error('Operation failed: $e');
}
```

## Examples

See the `/example` directory for complete examples:

- `aspire_example.dart` - Complete .NET Aspire integration with traces and logs
- `metrics_example.dart` - Comprehensive metrics example with all instrument types
- `http_client_example.dart` - HTTP client instrumentation example
- `composable_http_client_example.dart` - Advanced composable HTTP client example

Run examples:
```bash
dart run example/metrics_example.dart
dart run example/aspire_example.dart
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details.

## Resources

- [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otlp/)
- [.NET Aspire Dashboard](https://learn.microsoft.com/en-us/dotnet/aspire/)
- [OTLP Protocol](https://github.com/open-telemetry/opentelemetry-proto)
- [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)

## Support

For issues and questions:
- GitHub Issues: https://github.com/jamiewest/otlp-dart/issues
- OpenTelemetry Community: https://opentelemetry.io/community/
