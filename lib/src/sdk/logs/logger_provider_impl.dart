import '../../api/logs/logger.dart';
import '../../api/logs/logger_provider.dart';
import '../../sdk/resource/resource.dart';
import 'log_processor.dart';
import 'logger_impl.dart';

/// Implementation of LoggerProvider.
class LoggerProviderImpl implements LoggerProvider {
  final Resource resource;
  final LogRecordProcessor processor;
  final Map<String, Logger> _loggers = {};

  LoggerProviderImpl({
    required this.resource,
    required this.processor,
  });

  @override
  Logger getLogger(String name, {String? version}) {
    final key = '$name${version ?? ''}';

    return _loggers.putIfAbsent(key, () {
      final scope = InstrumentationScope(name: name, version: version);
      return LoggerImpl(
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
