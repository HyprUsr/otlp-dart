/// HTTP Semantic Conventions for OpenTelemetry
/// Based on: https://opentelemetry.io/docs/specs/semconv/http/http-spans/
class HttpSemanticConventions {
  // HTTP Request attributes
  static const String httpRequestMethod = 'http.request.method';
  static const String httpRequestBodySize = 'http.request.body.size';
  static const String httpRequestHeader = 'http.request.header';

  // HTTP Response attributes
  static const String httpResponseStatusCode = 'http.response.status_code';
  static const String httpResponseBodySize = 'http.response.body.size';
  static const String httpResponseHeader = 'http.response.header';

  // URL attributes
  static const String urlFull = 'url.full';
  static const String urlScheme = 'url.scheme';
  static const String urlPath = 'url.path';
  static const String urlQuery = 'url.query';

  // Network attributes
  static const String networkProtocolName = 'network.protocol.name';
  static const String networkProtocolVersion = 'network.protocol.version';
  static const String networkPeerAddress = 'network.peer.address';
  static const String networkPeerPort = 'network.peer.port';

  // Server attributes
  static const String serverAddress = 'server.address';
  static const String serverPort = 'server.port';

  // Error attributes
  static const String errorType = 'error.type';

  // User agent
  static const String userAgentOriginal = 'user_agent.original';

  // HTTP methods
  static const String methodGet = 'GET';
  static const String methodPost = 'POST';
  static const String methodPut = 'PUT';
  static const String methodDelete = 'DELETE';
  static const String methodPatch = 'PATCH';
  static const String methodHead = 'HEAD';
  static const String methodOptions = 'OPTIONS';

  /// Returns the span name for an HTTP client request
  static String getClientSpanName(String method) {
    return method;
  }

  /// Returns the span kind description
  static String getSpanKindDescription(bool isClient) {
    return isClient ? 'client' : 'server';
  }
}
