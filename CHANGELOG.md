# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Full metrics SDK implementation with all instrument types
- Counter instrument for monotonically increasing values
- UpDownCounter instrument for values that can increase or decrease
- Histogram instrument for value distributions with bucket boundaries
- ObservableGauge for callback-based current value reporting
- ObservableCounter for callback-based monotonically increasing values
- PeriodicMetricReader with configurable export intervals
- Delta temporality support for metrics
- Comprehensive test suite with 22 test cases covering all metrics functionality
- Histogram bucket boundary tests and statistical calculations (min/max/sum/count)
- Complex attribute type support (arrays, key-value lists)
- Concurrent metric recording tests
- Metrics example demonstrating real-world usage patterns

### Fixed
- Critical SDK bugs for .NET Aspire Dashboard compatibility
- HTTP/2 with Protobuf support for Aspire integration
- Attribute serialization for proper metric grouping
- Metric collection lifecycle and shutdown behavior

### Improved
- Test coverage from 4 to 22 comprehensive test cases
- Metrics SDK robustness and edge case handling
- Documentation with detailed metrics usage examples

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
- ✅ OTLP/HTTP2 Protobuf encoding for Aspire
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
