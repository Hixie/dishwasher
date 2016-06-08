import 'dart:async';
import 'dart:io';

import 'messages.dart';
import 'model.dart';

Stopwatch staleness = new Stopwatch();
Timer dirtyTimer;

const Duration kCoallesceDelay = const Duration(milliseconds: 100);
const Duration kMaxStaleness = const Duration(milliseconds: 800);

void handleWebSocketMessage(dynamic message) {
  List<String> parts;
  DateTime stamp;
  try {
    parts = message.split('\x00');
    verify(parts.length == 3, 'Invalid message (${parts.length} parts): "$message"');
    stamp = new DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0], radix: 10), isUtc: true);
    MessageHandler handler = handlers[parts[1]] ?? new DefaultHandler(parts[1]);
    handler.parse(stamp, parts[2]);
  } catch (e) {
    print('$stamp   ${parts[1]}  ${parts[2]}');
    print('${ " " * stamp.toString().length }   unable to parse: $e');
  }
  if (staleness.elapsed > kMaxStaleness) {
    dirtyTimer?.cancel();
    dirtyTimer = null;
    dishwasher.checkDirty();
  } else {
    dirtyTimer?.cancel();
    dirtyTimer = new Timer(kCoallesceDelay, dishwasher.checkDirty);
  }
}

void main() {
  print('GE GDF570SGFWW dishwasher model');
  HttpServer.bind('127.0.0.1', 2000)
    .then((HttpServer server) {
      server.listen((HttpRequest request) {
        WebSocketTransformer.upgrade(
          request,
          protocolSelector: (List<String> protocols) {
            return 'dishwasher-model';
          }
        ).then((WebSocket websocket) {
          websocket.listen(handleWebSocketMessage);
        });
      });
    }, onError: (error) => print("Error starting HTTP server: $error"));
}
