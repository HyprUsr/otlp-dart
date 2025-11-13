# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-01-13

### Added
- Initial release of otlp_dart
- OTLP/HTTP support for traces, metrics, and logs
- TracerProvider and Tracer API for distributed tracing
- LoggerProvider and Logger API for structured logging
- MeterProvider and Meter API foundations for metrics
- BatchSpanProcessor for efficient trace export
- BatchLogRecordProcessor for efficient log export
- Resource configuration with semantic attributes
- Built-in support for .NET Aspire Dashboard
- Automatic exception recording in spans
- Span events and links for distributed tracing
- Context propagation for parent-child span relationships
- Comprehensive example for Aspire Dashboard integration
- Full test suite for core functionality
- Detailed README with usage examples

### Features
- ✅ OTLP/HTTP JSON encoding
- ✅ Distributed tracing with nested spans
- ✅ Structured logging with severity levels
- ✅ Batch processing for performance
- ✅ Resource attributes for service identification
- ✅ Span kinds (server, client, internal, producer, consumer)
- ✅ Span status and events
- ✅ Exception recording with stack traces
- ✅ Trace context correlation in logs
- ✅ Configurable exporters and processors

[0.1.0]: https://github.com/jamiewest/otlp-dart/releases/tag/v0.1.0
