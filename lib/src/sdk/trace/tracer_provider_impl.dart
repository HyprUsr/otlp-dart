import '../../api/trace/tracer.dart';
import '../../api/trace/tracer_provider.dart';
import '../../sdk/resource/resource.dart';
import 'span_processor.dart';
import 'tracer_impl.dart';

/// Implementation of TracerProvider.
class TracerProviderImpl implements TracerProvider {

  TracerProviderImpl({
    required this.resource,
    required this.processor,
  });
  final Resource resource;
  final SpanProcessor processor;
  final Map<String, Tracer> _tracers = {};

  @override
  Tracer getTracer(String name, {String? version}) {
    final key = '$name${version ?? ''}';

    return _tracers.putIfAbsent(key, () {
      final scope = InstrumentationScope(name: name, version: version);
      return TracerImpl(
        scope: scope,
        resource: resource,
        processor: processor,
      );
    });
  }

  @override
  Future<void> shutdown() async {
    await processor.shutdown();
  }

  @override
  Future<void> forceFlush() async {
    await processor.forceFlush();
  }
}
