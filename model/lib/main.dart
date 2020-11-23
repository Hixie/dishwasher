import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'credentials.dart';
import 'database.dart';
import 'messages.dart';
import 'model.dart';

Stopwatch staleness = new Stopwatch()..start();
Timer dirtyTimer;

const Duration kCoallesceDelay = const Duration(milliseconds: 100);
const Duration kMaxStaleness = const Duration(milliseconds: 250);

final Dishwasher dishwasher = new Dishwasher(onLog: (String message) { log('model', message); });
DatabaseWritingClient database;

enum DishwasherStateSummary { unknown, idle, running }

bool ansiEnabled = false;
DishwasherStateSummary mostRecentState = DishwasherStateSummary.unknown;

Map<String, List<String>> _log = <String, List<String>>{};

void log(String category, String message) {
  if (ansiEnabled) {
    List<String> section = _log.putIfAbsent(category, () => <String>[]);
    section.add('${DateTime.now().toIso8601String()} $message');
    if (section.length > 4)
      section.removeAt(0);
  } else {
    print('$category: $message');
  }
}

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
    } catch (e, stack) {
      print('unable to parse: $message (${stack.toString().split("\n").first})');
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
    } catch (e, stack) {
      print('$stamp   $messageName  $payload');
      print('${ " " * stamp.toString().length }   unable to parse: $e (${stack.toString().split("\n").first})');
    }
  }
}

void updateDisplay({ bool force: false }) {
  if (ansiEnabled) {
    if (dishwasher.isDirty || force) {
      stdout.write('\u001B[?25l\u001B[H'); // hide cursor, and move cursor to top left
      printClear('GE GDF570SGFWW dishwasher model');
      printClear('▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔');
      dishwasher.printEverything(); // calls printClear below
      printClear('');
      for (String category in _log.keys) {
        for (String message in _log[category])
          printClear('$category $message');
      }
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

void configureDishwasherOutput(Dishwasher dishwasher) {
  if (ansiEnabled) {
    dishwasher.onPrint = printClear;
  } else {
    dishwasher.onPrint = print;
  }
}

void handleWebSocketMessage(dynamic message) {
  if (message is! String)
    return;
  staleness.start();
  new LogMessage.fromLogLine(message)?.dispatch(dishwasher);
  if (staleness.elapsed > kMaxStaleness) {
    applyUpdates();
  } else {
    dirtyTimer?.cancel();
    dirtyTimer = new Timer(kCoallesceDelay, () {
      applyUpdates();
    });
  }
}

void applyUpdates() {
  dirtyTimer?.cancel();
  dirtyTimer = null;
  updateDisplay();
  database?.send(dishwasher.encodeForDatabase().buffer.asUint8List());
  staleness.reset();
  staleness.stop();
}

void updateRemoteModel(Credentials credentials) {
  DishwasherStateSummary oldState = mostRecentState;
  if (dishwasher.isIdle)
    mostRecentState = DishwasherStateSummary.idle;
  else
    mostRecentState = DishwasherStateSummary.running;
  if (oldState != mostRecentState) {
    String message;
    switch (mostRecentState) {
      case DishwasherStateSummary.idle: message = 'dishwasherIdle'; break;
      case DishwasherStateSummary.running: message = 'dishwasherRunning'; break;
      default: message = 'dishwasherConfused'; break;
    }
    SecureSocket.connect(credentials.remyHost, credentials.remyPort).then((Socket socket) {
      socket
        ..handleError((e) { print('socket error: $e'); })
        ..encoding = utf8
        ..write('${credentials.remyUsername}\x00${credentials.remyPassword}\x00$message\x00\x00\x00')
        ..flush().then((sink) async {
          socket.close();
        });
    }, onError: (error) { log('remy', '$error'); });
  }
}

const int port = 2000;

void startServer({ Credentials credentials }) {
  print('Starting server...\n');
  configureDishwasherOutput(dishwasher);
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
            handleWebSocketMessage(message);
            if (credentials != null)
              updateRemoteModel(credentials);
          });
        });
      });
    }, onError: (error) => log('server', error));
}

final RegExp logFile = new RegExp(r'^sending to model: (.+)$');

void readLogs(List<String> arguments, { bool verbose: false }) {
  print('Loading archived logs...');
  for (String pathName in arguments) {
    final Directory directory = new Directory(pathName);
    final List<File> files = directory.listSync().whereType<File>().toList();
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
                  updateDisplay();
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

void main(List<String> arguments) async {
  print('GE GDF570SGFWW dishwasher model');
  print('▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔');
  final ArgParser parser = new ArgParser()
    ..addFlag(kColorArgument, help: 'Enable ANSI codes.', defaultsTo: false)
    ..addFlag(kServerArgument, help: 'Listen for further messages using a WebSocket on port $port.', defaultsTo: true)
    ..addFlag(kVerboseLogsArgument, help: 'Show updates when parsing logs.', defaultsTo: false)
    ..addOption(kHouseHubConfigurationArgument, help: 'Configuration file for a house hub to which to forward information (when server enabled).');
  final ArgResults parsedArguments = parser.parse(arguments);
  final String hubConfiguration = parsedArguments[kHouseHubConfigurationArgument];
  Credentials credentials;
  InternetAddress databaseHost;
  SecurityContext securityContext;
  if (hubConfiguration != null) {
    credentials = Credentials(hubConfiguration);
    securityContext = SecurityContext()..setTrustedCertificatesBytes(File(credentials.certificatePath).readAsBytesSync());
    List<InternetAddress> databaseHosts = await InternetAddress.lookup(credentials.databaseHost);
    if (databaseHosts.isEmpty) {
      print('Could not look up ${credentials.databaseHost}');
      exit(1);
    }
    databaseHost = databaseHosts.first;
  }
  if (parsedArguments[kVerboseLogsArgument]) {
    configureDishwasherOutput(dishwasher);
    readLogs(parsedArguments.rest, verbose: true);
  } else {
    readLogs(parsedArguments.rest);
  }
  print('Log parsing complete.');
  if (parsedArguments[kColorArgument])
    ansiEnabled = true;
  ProcessSignal.sigwinch.watch().forEach((ProcessSignal signal) { updateDisplay(force: true); });
  if (databaseHost != null) {
    database = new DatabaseWritingClient(
      databaseHost,
      credentials.databasePort,
      securityContext,
      credentials.databasePassword,
      onLog: (String message) { log('database', message); },
    );
  }
  if (parsedArguments[kServerArgument]) {
    startServer(credentials: credentials);
  } else {
    configureDishwasherOutput(dishwasher);
    dishwasher.printEverything();
  }
}
