import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'messages.dart';
import 'model.dart';

Stopwatch staleness = new Stopwatch();
Timer dirtyTimer;

const Duration kCoallesceDelay = const Duration(milliseconds: 500);
const Duration kMaxStaleness = const Duration(milliseconds: 3500);

final Dishwasher dishwasher = new Dishwasher();

enum DishwasherStateSummary { unknown, idle, running }

DishwasherStateSummary mostRecentState = DishwasherStateSummary.unknown;

class LogMessage {
  LogMessage(this.stamp, this.handler, this.payload, { this.messageName });
  factory LogMessage.fromLogLine(String message) {
    try {
      final List<String> parts = message.split('\x00');
      verify(parts.length == 3, 'Invalid message (${parts.length} parts): "$message"');
      DateTime stamp = new DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0], radix: 10), isUtc: true);
      if (dishwasher.lastMessageTimestamp != null && stamp.compareTo(dishwasher.lastMessageTimestamp) < 0)
        return null; // ignore old messages
      final MessageHandler handler = handlers[parts[1]] ?? new DefaultHandler(parts[1]);
      return new LogMessage(stamp, handler, parts[2], messageName: parts[1]);
    } catch (e) {
      print('unable to parse: $message');
    }
    return null;
  }
  final DateTime stamp;
  final MessageHandler handler;
  final String payload;
  final String messageName;
  void dispatch(Dishwasher dishwasher) {
    try {
      dishwasher.lastMessageTimestamp = stamp;  
      handler.parse(dishwasher, stamp, payload);
    } catch (e) {
      print('$stamp   $messageName  $payload');
      print('${ " " * stamp.toString().length }   unable to parse: $e');
    }
  }
}

void updateDisplay(bool ansiEnabled) {
  if (ansiEnabled) {
    if (dishwasher.isDirty) {
      stdout.write('\u001B[?25l\u001B[H'); // hide cursor, and move cursor to top left
      printClear('GE GDF570SGFWW dishwasher model');
      printClear('▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔');
      dishwasher.printEverything(); // calls printClear below
      stdout.write('\u001B[J\u001B[?25h'); // clear rest of screen, and show cursor again
    }
  } else {
    dishwasher.printUpdates();
  }
}

void printClear(String lines) {
  for (String line in lines.split('\n'))
    stdout.write('$line\u001B[K\n');
}

void configureDishwasherOutput(Dishwasher dishwasher, bool ansiEnabled) {
  if (ansiEnabled) {
    dishwasher.enableNotifications = false;
    dishwasher.onPrint = printClear;
  } else {
    dishwasher.enableNotifications = true;
    dishwasher.onPrint = print;
  }
}

void handleWebSocketMessage(dynamic message, bool ansiEnabled) {
  if (message is! String)
    return;
  new LogMessage.fromLogLine(message)?.dispatch(dishwasher);
  if (staleness.elapsed > kMaxStaleness) {
    dirtyTimer?.cancel();
    dirtyTimer = null;
    updateDisplay(ansiEnabled);
  } else {
    dirtyTimer?.cancel();
    dirtyTimer = new Timer(kCoallesceDelay, () { updateDisplay(ansiEnabled); });
  }
}

void updateRemoteModel(String hubConfiguration) {
  DishwasherStateSummary oldState = mostRecentState;
  if (dishwasher.isIdle)
    mostRecentState = DishwasherStateSummary.idle;
  else
    mostRecentState = DishwasherStateSummary.running;
  if (oldState != mostRecentState) {
    final List<String> config = new File(hubConfiguration).readAsLinesSync();
    final String hubServer = config[0];
    final int port = int.parse(config[1]);
    final String username = config[2];
    final String password = config[3];
    String message;
    switch (mostRecentState) {
      case DishwasherStateSummary.idle: message = 'dishwasherIdle'; break;
      case DishwasherStateSummary.running: message = 'dishwasherRunning'; break;
      default: message = 'dishwasherConfused'; break;
    }
    SecureSocket.connect(hubServer, port).then((Socket socket) {
      socket
        ..handleError((e) { print('socket error: $e'); })
        ..encoding = UTF8
        ..write('$username\x00$password\x00$message\x00\x00\x00')
        ..flush().then((IOSink sink) {
          socket.close();
        });
    }, onError: (e) { print('error: $e'); });
  }
}

const int port = 2000;

void startServer({ bool ansiEnabled: false, String hubConfiguration }) {
  print('Starting server...\n');
  configureDishwasherOutput(dishwasher, ansiEnabled);
  HttpServer.bind('127.0.0.1', port)
    .then((HttpServer server) {
      server.listen((HttpRequest request) {
        WebSocketTransformer.upgrade(
          request,
          protocolSelector: (List<String> protocols) {
            return 'dishwasher-model';
          }
        ).then((WebSocket websocket) {
          websocket.listen((dynamic message) {
            handleWebSocketMessage(message, ansiEnabled);
            if (hubConfiguration != null)
              updateRemoteModel(hubConfiguration);
          });
        });
      });
    }, onError: (error) => print("Error starting server: $error"));
}

final RegExp logFile = new RegExp(r'^sending to model: (.+)$');

void readLogs(List<String> arguments, { bool ansiEnabled: false, bool verbose: false }) {
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
          final LogMessage message = new LogMessage.fromLogLine(parts.group(1));
          if (message != null) {
            if (dishwasher.lastMessageTimestamp != null) {
              assert(message.stamp.compareTo(dishwasher.lastMessageTimestamp) >= 0);
              if (verbose) {
                if (message.stamp.difference(dishwasher.lastMessageTimestamp) >= kCoallesceDelay)
                  updateDisplay(ansiEnabled);
              }
            }
            message.dispatch(dishwasher);
          }
        }
      }
    }
  }
}

const String kColorArgument = 'ansi';
const String kServerArgument = 'server';
const String kVerboseLogsArgument = 'show-logs';
const String kHouseHubConfigurationArgument = 'hub-config';

void main(List<String> arguments) {
  print('GE GDF570SGFWW dishwasher model');
  print('▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔');
  final ArgParser parser = new ArgParser()
    ..addFlag(kColorArgument, help: 'Enable ANSI codes.', defaultsTo: false)
    ..addFlag(kServerArgument, help: 'Listen for further messages using a WebSocket on port $port.', defaultsTo: true)
    ..addFlag(kVerboseLogsArgument, help: 'Show updates when parsing logs.', defaultsTo: false)
    ..addOption(kHouseHubConfigurationArgument, help: 'Configuration file for a house hub to which to forward information (when server enabled).');
  final ArgResults parsedArguments = parser.parse(arguments);
  final bool ansiEnabled = parsedArguments[kColorArgument];
  if (parsedArguments[kVerboseLogsArgument]) {
    configureDishwasherOutput(dishwasher, ansiEnabled);
    readLogs(parsedArguments.rest, ansiEnabled: ansiEnabled, verbose: true);
  } else {
    readLogs(parsedArguments.rest, ansiEnabled: ansiEnabled);
  }
  print('Log parsing complete.');
  String hubConfiguration = parsedArguments[kHouseHubConfigurationArgument];
  if (parsedArguments[kServerArgument]) {
    startServer(ansiEnabled: ansiEnabled, hubConfiguration: hubConfiguration);
  } else {
    configureDishwasherOutput(dishwasher, ansiEnabled);
    dishwasher.printEverything();
  }
}

