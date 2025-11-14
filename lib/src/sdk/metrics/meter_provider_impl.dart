import '../../api/metrics/meter_provider.dart';
import '../../api/metrics/meter.dart';
import '../../sdk/resource/resource.dart';
import 'meter_impl.dart';
import 'metric_reader.dart';

/// Implementation of the MeterProvider interface.
class MeterProviderImpl implements MeterProvider {

  MeterProviderImpl({
    required this.resource,
    required this.reader,
  });
  final Resource resource;
  final MetricReader reader;
  final Map<String, MeterImpl> _meters = {};
  bool _shutdown = false;

  @override
  Meter getMeter(String name, {String? version, String? schemaUrl}) {
    if (_shutdown) {
      throw StateError('MeterProvider has been shut down');
    }

    final key = '$name:${version ?? ''}';
    return _meters.putIfAbsent(key, () {
      return MeterImpl(
        scope: InstrumentationScope(
          name: name,
          version: version,
        ),
        resource: resource,
        reader: reader,
      );
    });
  }

  @override
  Future<void> forceFlush() async {
    await reader.forceFlush();
  }

  @override
  Future<void> shutdown() async {
    if (_shutdown) return;
    _shutdown = true;
    await reader.shutdown();
  }
}
