import 'package:test/test.dart';
import 'package:otlp_dart/otlp_dart.dart';
import 'package:otlp_dart/src/sdk/trace/tracer_provider_impl.dart';
import 'package:otlp_dart/src/sdk/trace/span_processor.dart';
import 'package:otlp_dart/src/sdk/trace/recording_span.dart';
import 'package:otlp_dart/src/sdk/trace/span_exporter.dart';

class TestSpanExporter implements SpanExporter {
  final List<RecordingSpan> exportedSpans = [];

  @override
  Future<void> export(List<RecordingSpan> spans) async {
    exportedSpans.addAll(spans);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

void main() {
  group('Tracer', () {
    late Resource resource;
    late TestSpanExporter exporter;
    late TracerProviderImpl tracerProvider;
    late Tracer tracer;

    setUp(() {
      resource = Resource.create(serviceName: 'test-service');
      exporter = TestSpanExporter();
      tracerProvider = TracerProviderImpl(
        resource: resource,
        processor: SimpleSpanProcessor(exporter),
      );
      tracer = tracerProvider.getTracer('test');
    });

    tearDown(() async {
      await tracerProvider.shutdown();
    });

    test('creates a basic span', () {
      final span = tracer.startSpan('test-span');

      expect(span.isRecording, isTrue);
      expect(span.context.isValid, isTrue);

      span.end();

      expect(span.isRecording, isFalse);
      expect(exporter.exportedSpans.length, equals(1));
    });

    test('creates span with attributes', () {
      final span = tracer.startSpan('test-span');
      span.setAttribute('key', AttributeValue.string('value'));
      span.setAttribute('number', AttributeValue.int(42));
      span.end();

      final recordedSpan = exporter.exportedSpans.first;
      expect(recordedSpan.name, equals('test-span'));
      expect(recordedSpan.toJson()['attributes'].length, equals(2));
    });

    test('creates nested spans', () {
      final parent = tracer.startSpan('parent');
      final child = tracer.startSpan('child', parent: parent);

      expect(child.context.traceId, equals(parent.context.traceId));

      child.end();
      parent.end();

      expect(exporter.exportedSpans.length, equals(2));
    });

    test('records exceptions', () {
      final span = tracer.startSpan('error-span');

      try {
        throw Exception('Test error');
      } catch (e, stackTrace) {
        span.recordException(e, stackTrace: stackTrace);
      }

      span.end();

      final recordedSpan = exporter.exportedSpans.first as RecordingSpan;
      final events = recordedSpan.toJson()['events'] as List;
      expect(events.length, equals(1));
      expect(events.first['name'], equals('exception'));
    });

    test('withSpan automatically ends span', () async {
      var executed = false;

      tracer.withSpan('test', (span) {
        executed = true;
        expect(span.isRecording, isTrue);
        return 42;
      });

      expect(executed, isTrue);
      expect(exporter.exportedSpans.length, equals(1));
      expect(exporter.exportedSpans.first.isRecording, isFalse);
    });

    test('withSpanAsync automatically ends span', () async {
      var executed = false;

      await tracer.withSpanAsync('test', (span) async {
        executed = true;
        expect(span.isRecording, isTrue);
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      expect(executed, isTrue);
      expect(exporter.exportedSpans.length, equals(1));
      expect(exporter.exportedSpans.first.isRecording, isFalse);
    });

    test('withSpanAsync records exceptions', () async {
      try {
        await tracer.withSpanAsync('error', (span) async {
          throw Exception('Async error');
        });
        fail('Should have thrown exception');
      } catch (e) {
        expect(e.toString(), contains('Async error'));
      }

      expect(exporter.exportedSpans.length, equals(1));
      final recordedSpan = exporter.exportedSpans.first as RecordingSpan;
      final events = recordedSpan.toJson()['events'] as List;
      expect(events.length, equals(1));
      expect(events.first['name'], equals('exception'));
    });

    test('span has correct kind', () {
      final span = tracer.startSpan('server-span', kind: SpanKind.server);
      span.end();

      final recordedSpan = exporter.exportedSpans.first as RecordingSpan;
      expect(recordedSpan.kind, equals(SpanKind.server));
    });

    test('span status can be set', () {
      final span = tracer.startSpan('test');
      span.setStatus(SpanStatus.error('Something went wrong'));
      span.end();

      final recordedSpan = exporter.exportedSpans.first as RecordingSpan;
      final status = recordedSpan.toJson()['status'];
      expect(status['code'], equals(StatusCode.error.toInt()));
      expect(status['message'], equals('Something went wrong'));
    });

    test('span events are recorded', () {
      final span = tracer.startSpan('test');
      span.addEvent('event1');
      span.addEvent('event2', attributes: {
        'key': AttributeValue.string('value'),
      });
      span.end();

      final recordedSpan = exporter.exportedSpans.first as RecordingSpan;
      final events = recordedSpan.toJson()['events'] as List;
      expect(events.length, equals(2));
      expect(events[0]['name'], equals('event1'));
      expect(events[1]['name'], equals('event2'));
    });
  });

  group('Resource', () {
    test('creates resource with attributes', () {
      final resource = Resource.create(
        serviceName: 'my-service',
        serviceVersion: '1.0.0',
        additionalAttributes: {'env': 'prod'},
      );

      final json = resource.toJson();
      final attrs = json['attributes'] as List;

      expect(attrs.length, greaterThanOrEqualTo(2));
    });
  });

  group('SpanContext', () {
    test('validates context', () {
      final validContext = SpanContext(
        traceId: '0123456789abcdef0123456789abcdef',
        spanId: '0123456789abcdef',
      );

      expect(validContext.isValid, isTrue);
      expect(validContext.isSampled, isTrue);

      final invalidContext = SpanContext(
        traceId: '',
        spanId: '',
      );

      expect(invalidContext.isValid, isFalse);
    });
  });
}
