import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import 'messages.dart';
import 'model.dart';

Stopwatch staleness = new Stopwatch();
Timer dirtyTimer;

const Duration kCoallesceDelay = const Duration(milliseconds: 1500);
const Duration kMaxStaleness = const Duration(milliseconds: 3500);

final Dishwasher dishwasher = new Dishwasher();

void processMessage(String message) {
  List<String> parts = message.split('\x00');
  DateTime stamp;
  try {
    verify(parts.length == 3, 'Invalid message (${parts.length} parts): "$message"');
    stamp = new DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0], radix: 10), isUtc: true);
    assert(stamp.compareTo(dishwasher.lastMessageTimestamp) >= 0);
    MessageHandler handler = handlers[parts[1]] ?? new DefaultHandler(parts[1]);
    handler.parse(dishwasher, stamp, parts[2]);
    dishwasher.lastMessageTimestamp = stamp;
  } catch (e) {
    print('$stamp   ${parts[1]}  ${parts[2]}');
    print('${ " " * stamp.toString().length }   unable to parse: $e');
  }
}

void updateDisplay(bool ansiEnabled) {
  if (ansiEnabled) {
    if (dishwasher.isDirty) {
      stdout.write('\u001B[H'); // clear screen and move cursor to top left
      printClear('GE GDF570SGFWW dishwasher model');
      printClear('▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔');
      dishwasher.printEverything(); // calls printClear below
      stdout.write('\u001B[J');
    }
  } else {
    dishwasher.printUpdates();
  }
}

void printClear(String lines) {
  for (String line in lines.split('\n'))
    stdout.write('$line\u001B[K\n');
}

void handleWebSocketMessage(dynamic message, bool ansiEnabled) {
  if (message is! String)
    return;
  processMessage(message);
  if (staleness.elapsed > kMaxStaleness || ansiEnabled) {
    dirtyTimer?.cancel();
    dirtyTimer = null;
    updateDisplay(ansiEnabled);
  } else {
    dirtyTimer?.cancel();
    dirtyTimer = new Timer(kCoallesceDelay, () { updateDisplay(ansiEnabled); });
  }
}

void startServer(bool ansiEnabled) {
  print('Starting server...\n');
  if (ansiEnabled) {
    dishwasher.onPrint = printClear;
  } else {
    dishwasher.enableNotifications = true;
    dishwasher.onPrint = print;
  }
  HttpServer.bind('127.0.0.1', 2000)
    .then((HttpServer server) {
      server.listen((HttpRequest request) {
        WebSocketTransformer.upgrade(
          request,
          protocolSelector: (List<String> protocols) {
            return 'dishwasher-model';
          }
        ).then((WebSocket websocket) {
          websocket.listen((dynamic message) { handleWebSocketMessage(message, ansiEnabled); });
        });
      });
    }, onError: (error) => print("Error starting server: $error"));
}

final RegExp logFile = new RegExp(r'^sending to model: (.+)$');

void readLogs(List<String> arguments) {
  print('Loading archived logs...');
  for (String pathName in arguments) {
    final Directory directory = new Directory(pathName);
    final List<FileSystemEntity> files = directory.listSync();
    files.removeWhere((FileSystemEntity entry) => entry is! File);
    files.sort((File a, File b) => a.path.compareTo(b.path));
    for (File entry in files) {
      for (String line in entry.readAsLinesSync()) {
        final Match parts = logFile.matchAsPrefix(line);
        if (parts != null) {
          processMessage(parts.group(1));
        }
      }
    }
  }
}

const String kColorArgument = 'ansi';

void main(List<String> arguments) {
  print('GE GDF570SGFWW dishwasher model');
  print('▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔');
  final ArgParser parser = new ArgParser()
    ..addFlag(kColorArgument, help: 'Enable ANSI codes', defaultsTo: false);
  final ArgResults parsedArguments = parser.parse(arguments);
  readLogs(parsedArguments.rest);
  startServer(parsedArguments[kColorArgument]);
}
