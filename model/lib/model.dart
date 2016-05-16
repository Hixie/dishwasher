import 'dart:convert';
import 'dart:io';

void verify(bool condition, [String message = 'Protocol error.']) {
  if (!condition)
    throw message;
}

bool isByte(dynamic value) {
  verify(value is int);
  verify(value >= 0);
  verify(value <= 255);
}

bool isWord(dynamic value) {
  verify(value is int);
  verify(value >= 0);
  verify(value <= 65536);
}

enum DryOptions { idle, heated }
enum WashTemperature { normal, boost, sanitize }
enum UserCycleSelection { autosense, heavy, normal, light }

class Dishwasher {
  bool _dirty = false;

  WashTemperature get washTemperature => _washTemperature;
  WashTemperature _washTemperature = WashTemperature.normal;
  set washTemperature(WashTemperature value) {
    if (_washTemperature == value)
      return;
    _washTemperature = value;
    _dirty = true;
  }

  UserCycleSelection get userCycleSelection => _userCycleSelection;
  UserCycleSelection _userCycleSelection = UserCycleSelection.autosense;
  set userCycleSelection(UserCycleSelection value) {
    if (_userCycleSelection == value)
      return;
    _userCycleSelection = value;
    _dirty = true;
  }

  int get delay => _delay;
  int _delay = 0;
  set delay(int value) {
    if (_delay == value)
      return;
    _delay = value;
    _dirty = true;
  }

  bool get sabbathMode => _sabbathMode;
  bool _sabbathMode = false;
  set sabbathMode(bool value) {
    if (_sabbathMode == value)
      return;
    _sabbathMode = value;
    _dirty = true;
  }

  bool get uiLocked => _uiLocked;
  bool _uiLocked = false;
  set uiLocked(bool value) {
    if (_uiLocked == value)
      return;
    _uiLocked = value;
    _dirty = true;
  }

  bool get demo => _demo;
  bool _demo = false;
  set demo(bool value) {
    if (_demo == value)
      return;
    _demo = value;
    _dirty = true;
  }

  bool get mute => _mute;
  bool _mute = false;
  set mute(bool value) {
    if (_mute == value)
      return;
    _mute = value;
    _dirty = true;
  }

  bool get steam => _steam;
  bool _steam = false;
  set steam(bool value) {
    if (_steam == value)
      return;
    _steam = value;
    _dirty = true;
  }

  DryOptions get dryOptions => _dryOptions;
  DryOptions _dryOptions = DryOptions.idle;
  set dryOptions(DryOptions value) {
    if (_dryOptions == value)
      return;
    _dryOptions = value;
    _dirty = true;
  }

  bool get rinseAidEnabled => _rinseAidEnabled;
  bool _rinseAidEnabled = false;
  set rinseAidEnabled(bool value) {
    if (_rinseAidEnabled == value)
      return;
    _rinseAidEnabled = value;
    _dirty = true;
  }

  void printButtons() {
    List<String> settings = <String>[];
    if (delay > 0)
      settings.add('Delay Hours: ${delay}h');
    switch (userCycleSelection) {
      case UserCycleSelection.autosense: settings.add('AutoSense'); break;
      case UserCycleSelection.heavy: settings.add('Heavy'); break;
      case UserCycleSelection.normal: settings.add('Normal'); break;
      case UserCycleSelection.light: settings.add('Light'); break;
    }
    if (steam)
      settings.add('Steam');
    if (rinseAidEnabled)
      settings.add('Rinse Aid Enabled');
    switch (washTemperature) {
      case WashTemperature.normal: break;
      case WashTemperature.boost: settings.add('Boost'); break;
      case WashTemperature.sanitize: settings.add('Sanitize'); break;
    }
    switch (dryOptions) {
      case DryOptions.idle: break;
      case DryOptions.heated: settings.add('Heated Dry'); break;
    }
    if (uiLocked)
      settings.add('Lock Controls');
    if (sabbathMode)
      settings.add('Sabbath Mode');
    String demoUI = demo ? '┤ DEMO ├' : '';
    String muteUI = mute ? '┤ MUTED ├' : '';
    int margin = 5;
    final String buttons = '│ ${ settings.join("  ").padRight(margin * 3 + demoUI.length + muteUI.length) } │';
    String leaderLeft = '┌${"─" * margin}$demoUI';
    String leaderRight = '$muteUI${"─" * margin}┐';
    int innerWidth = buttons.length - leaderLeft.length - leaderRight.length;
    String leader = '$leaderLeft${ "─" * innerWidth }$leaderRight';
    String footer = '└${ "─" * (leader.length - 2) }┘';
    print(leader);
    print(buttons);
    print(footer);
  }

  void checkDirty() {
    if (_dirty) {
      printButtons();
      _dirty = false;
    }
  }
}
final Dishwasher dishwasher = new Dishwasher();

abstract class MessageHandler {
  String get name => runtimeType.toString();
  void parse(DateTime stamp, String data);
  void parseFail() {
    throw 'Unexpected data from dishwasher.';
  }
}

abstract class IgnoredMessageHandler extends MessageHandler {
  void parse(DateTime stamp, String data) {
    print('$stamp   ignoring field "$name": $data');
  }
}

class DefaultHandler extends IgnoredMessageHandler {
  DefaultHandler(this._name);
  final String _name;
  String get name => _name;
}

class UserConfigurationHandler extends MessageHandler {
  void parse(DateTime stamp, String data) {
    dynamic decodedData = JSON.decode(data);
    verify(decodedData is List<dynamic>);
    verify(decodedData.length == 3);
    verify(!decodedData.any((dynamic value) => value is! int));
    int byte1 = decodedData[0];
    int byte2 = decodedData[1];
    int byte3 = decodedData[2];
    // expand out the data
    int delay;
    switch (byte1 & 0x0F) {
      case 0: delay = 0; break;
      case 1: delay = 2; break;
      case 2: delay = 4; break;
      case 3: delay = 8; break;
    }
    int zone = (byte1 & 0x30) >> 4;
    if (zone > 0)
      parseFail(); // never seen with this dishwasher
    bool demo = (byte1 & 0x40) > 0;
    bool mute = (byte1 & 0x80) > 0; // press Heated Dry five (?) times in a row to toggle
    bool steam = (byte2 & 0x01) > 0;
    bool uiLocked = (byte2 & 0x02) > 0;
    DryOptions dryOptions;
    switch ((byte2 & 0x0C) >> 2) {
      case 0: dryOptions = DryOptions.idle; break;
      case 1: dryOptions = DryOptions.heated; break;
      default: parseFail(); // never seen 2 or 3 with this dishwasher
    }
    WashTemperature washTemperature;
    switch ((byte2 & 0x70) >> 4) {
      case 0: washTemperature = WashTemperature.normal; break;
      case 1: washTemperature = WashTemperature.boost; break;
      case 2: washTemperature = WashTemperature.sanitize; break;
      default: parseFail(); // never seen 3-7 with this dishwasher
    }
    bool rinseAidEnabled = (byte2 & 0x80) > 0; // press Steam five times in a row to toggle
    bool bottleBlast = (byte3 & 0x01) > 0; // not present on this dishwasher
    if (bottleBlast)
      parseFail(); // never seen with this dishwasher
    UserCycleSelection userCycleSelection;
    switch ((byte3 & 0x1E) >> 1) {
      case 0: userCycleSelection = UserCycleSelection.autosense; break;
      case 1: userCycleSelection = UserCycleSelection.heavy; break;
      case 2: userCycleSelection = UserCycleSelection.normal; break;
      case 3: userCycleSelection = UserCycleSelection.light; break;
      default: parseFail(); // never seen 4-15 with this dishwasher
    }
    bool leakDetect = (byte3 & 0x20) > 0; // no way to toggle with this dishwasher
    if (!leakDetect)
      parseFail(); // never seen with this dishwasher
    bool sabbathMode = (byte3 & 0x40) > 0; // hold start and wash temp buttons for five seconds to toggle
    if ((byte3 & 0x80) > 0)
      parseFail(); // never seen with this dishwasher

    dishwasher.delay = delay;
    // dishwasher.zone = zone;
    dishwasher.demo = demo;
    dishwasher.mute = mute;
    dishwasher.steam = steam;
    dishwasher.uiLocked = uiLocked;
    dishwasher.dryOptions = dryOptions;
    dishwasher.washTemperature = washTemperature;
    dishwasher.rinseAidEnabled = rinseAidEnabled;
    // dishwasher.bottleBlast = bottleBlast;
    dishwasher.userCycleSelection = userCycleSelection;
    // dishwasher.leakDetect = leakDetect;
    dishwasher.sabbathMode = sabbathMode;
  }
}

class CycleDataHandler extends MessageHandler {
  CycleDataHandler(this._cycle);
  final int _cycle;
  String get name => 'cycleData$_cycle';

  void parse(DateTime stamp, String data) {
    dynamic decodedData = JSON.decode(data);
    verify(decodedData is Map<dynamic, dynamic>);
    verify(decodedData['cycleNumber'] is int);
    verify(isByte(decodedData['cycleMinimumTemperatureInFahrenheit']));
    verify(isByte(decodedData['cycleMaximumTemperatureInFahrenheit']));
    verify(isByte(decodedData['cycleFinalTemperatureInFahrenheit']));
    verify(isWord(decodedData['cycleMinimumTurbidityInNTU']));
    verify(isWord(decodedData['cycleMaximumTurbidityInNTU']));
    verify(decodedData['cycleTime'] is int);
    verify(decodedData['cycleCompleted'] is int);
    verify(decodedData['cycleDurationInMinutes'] is int);
    // ...
  }
}

class OperatingModeHandler extends IgnoredMessageHandler { }
class CycleStateHandler extends IgnoredMessageHandler { }
class CycleStatusHandler extends IgnoredMessageHandler { }
class DoorCountHandler extends IgnoredMessageHandler { }
class RemindersHandler extends IgnoredMessageHandler { }
class CycleCountsHandler extends IgnoredMessageHandler { }
class ErrorsHandler extends IgnoredMessageHandler { }
class RatesHandler extends IgnoredMessageHandler { }
class ContinuousCycleHandler extends IgnoredMessageHandler { }
class AnalogDataHandler extends IgnoredMessageHandler { }
class DryDrainCountersHandler extends IgnoredMessageHandler { }
class PersonalityHandler extends IgnoredMessageHandler { }
class DisabledFeaturesHandler extends IgnoredMessageHandler { }
class ControlLockHandler extends IgnoredMessageHandler { }

final Map<String, MessageHandler> handlers = <String, MessageHandler>{
  'userConfiguration': new UserConfigurationHandler(),
  'cycleData0': new CycleDataHandler(0),
  'cycleData1': new CycleDataHandler(1),
  'cycleData2': new CycleDataHandler(2),
  'cycleData3': new CycleDataHandler(3),
  'cycleData4': new CycleDataHandler(4),
  'operatingMode': new OperatingModeHandler(),
  'cycleState': new CycleStateHandler(),
  'cycleStatus': new CycleStatusHandler(),
  'doorCount': new DoorCountHandler(),
  'reminders': new RemindersHandler(),
  'cycleCounts': new CycleCountsHandler(),
  'error': new ErrorsHandler(),
  'rates': new RatesHandler(),
  'continuousCycle': new ContinuousCycleHandler(),
  'analogData': new AnalogDataHandler(),
  'dryDrainCounters': new DryDrainCountersHandler(),
  'personality': new PersonalityHandler(),
  'disabledFeatures': new DisabledFeaturesHandler(),
  'controlLock': new ControlLockHandler(),
};

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
    print('$stamp   $parts[1]  $parts[2]');
    print('unable to parse: $e');
  }
  dishwasher.checkDirty();
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
