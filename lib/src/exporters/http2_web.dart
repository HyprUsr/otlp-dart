/// Web implementation for HTTP/2 transport.
/// On web, HTTP/2 is handled automatically by the browser's fetch API.
library;

import 'http2_stub.dart';

/// Creates an HTTP/2 transport connection for web.
/// On web platforms, HTTP/2 is not directly accessible via sockets.
/// This throws an error directing users to use HTTP/1.1 exporters or
/// browser-native fetch which handles HTTP/2 automatically.
Future<Http2Transport> createHttp2Transport(String host, int port) {
  throw UnsupportedError(
    'HTTP/2 via sockets is not supported in web browsers. '
    'The browser automatically handles HTTP/2 for fetch/XHR requests. '
    'For OTLP on web, use HTTP/1.1 exporters (without useHttp2 flag) '
    'or implement a custom exporter using browser fetch API.',
  );
}
