/// IO implementation for HTTP/2 transport using dart:io sockets.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:http2/http2.dart';
import 'http2_stub.dart';

/// Creates an HTTP/2 transport connection using dart:io Socket.
Future<Http2Transport> createHttp2Transport(String host, int port) async {
  final socket = await Socket.connect(host, port);
  return _IOHttp2Transport(socket);
}

class _IOHttp2Transport implements Http2Transport {

  _IOHttp2Transport(Socket socket)
      : _transport = ClientTransportConnection.viaSocket(socket);
  final ClientTransportConnection _transport;

  @override
  Future<Http2Response> request({
    required String method,
    required String path,
    required String scheme,
    required String authority,
    required Map<String, String> headers,
    required Uint8List body,
  }) async {
    final stream = _transport.makeRequest(
      [
        Header.ascii(':method', method),
        Header.ascii(':path', path),
        Header.ascii(':scheme', scheme),
        Header.ascii(':authority', authority),
        ...headers.entries.map(
          (e) => Header.ascii(e.key.toLowerCase(), e.value),
        ),
      ],
      endStream: false,
    );

    stream.outgoingMessages.add(DataStreamMessage(body));
    await stream.outgoingMessages.close();

    final responseData = <int>[];
    var statusCode = 0;

    await for (final message in stream.incomingMessages) {
      if (message is HeadersStreamMessage) {
        for (final header in message.headers) {
          final headerName = String.fromCharCodes(header.name);
          if (headerName == ':status') {
            statusCode = int.parse(String.fromCharCodes(header.value));
          }
        }
      } else if (message is DataStreamMessage) {
        responseData.addAll(message.bytes);
      }
    }

    return Http2Response(
      statusCode: statusCode,
      body: responseData,
    );
  }

  @override
  Future<void> finish() async {
    await _transport.finish();
  }
}
