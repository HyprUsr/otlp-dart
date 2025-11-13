/// Stub implementation for HTTP/2 transport.
/// This file is used when no platform-specific implementation is available.

import 'dart:typed_data';

/// Creates an HTTP/2 transport connection.
/// This is a stub that throws an error. Platform-specific implementations
/// should override this.
Future<Http2Transport> createHttp2Transport(String host, int port) {
  throw UnsupportedError(
    'HTTP/2 is not supported on this platform. '
    'Use HTTP/1.1 exporters or run on a platform with HTTP/2 support.',
  );
}

/// Abstract interface for HTTP/2 transport.
abstract class Http2Transport {
  Future<Http2Response> request({
    required String method,
    required String path,
    required String scheme,
    required String authority,
    required Map<String, String> headers,
    required Uint8List body,
  });

  Future<void> finish();
}

/// HTTP/2 response.
class Http2Response {
  final int statusCode;
  final List<int> body;

  Http2Response({
    required this.statusCode,
    required this.body,
  });
}
