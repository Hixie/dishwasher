import 'dart:convert';

import 'model.dart';

void verify(bool condition, [String message = 'Protocol error.']) {
  if (!condition)
    throw message;
}

bool isBit(dynamic value) => value is int && value >= 0 && value <= 1;
bool isByte(dynamic value) => value is int && value >= 0 && value <= 255;
bool isWord(dynamic value) => value is int && value >= 0 && value <= 65536;

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
  int get cycle => _cycle;
  final int _cycle;
  String get name => 'cycleData$_cycle';

  void parse(DateTime stamp, String data) {
    dynamic decodedData = JSON.decode(data);
    verify(decodedData is Map<dynamic, dynamic>, 'cycleData$_cycle data not a map');
    verify(decodedData['cycleNumber'] is int, 'cycleData$_cycle.cycleNumber not a number');
    verify(isByte(decodedData['cycleMinimumTemperatureInFahrenheit']), 'cycleData$_cycle.cycleMinimumTemperatureInFahrenheit not a byte');
    verify(isByte(decodedData['cycleMaximumTemperatureInFahrenheit']), 'cycleData$_cycle.cycleMaximumTemperatureInFahrenheit not a byte');
    verify(isByte(decodedData['cycleFinalCirculationTemperatureInFahrenheit']), 'cycleData$_cycle.cycleFinalCirculationTemperatureInFahrenheit not a byte');
    verify(isWord(decodedData['cycleMinimumTurbidityInNTU']), 'cycleData$_cycle.cycleMinimumTurbidityInNTU not a word');
    verify(isWord(decodedData['cycleMaximumTurbidityInNTU']), 'cycleData$_cycle.cycleMaximumTurbidityInNTU not a word');
    verify(decodedData['cycleTime'] is int, 'cycleData$_cycle.cycleTime not a number');
    verify(isBit(decodedData['cycleCompleted']), 'cycleData$_cycle.cycleCompleted not a single bit');
    verify(decodedData['cycleDurationInMinutes'] is int, 'cycleData$_cycle.cycleDurationInMinutes not a number');
    final int minimumTemperature = decodedData['cycleMinimumTemperatureInFahrenheit'];
    final int maximumTemperature = decodedData['cycleMaximumTemperatureInFahrenheit'];
    verify((minimumTemperature < maximumTemperature) || (minimumTemperature == 255 && maximumTemperature == 0));
    final int finalCirculationTemperature = decodedData['cycleFinalCirculationTemperatureInFahrenheit'];
    final int minimumTurbidity = decodedData['cycleMinimumTurbidityInNTU'];
    final int maximumTurbidity = decodedData['cycleMaximumTurbidityInNTU'];
    verify((minimumTurbidity < maximumTurbidity) || (minimumTurbidity == 65535 && maximumTurbidity == 0));
    final CycleData cycleData = new CycleData(
      number: decodedData['cycleNumber'],
      minimumTemperature: minimumTemperature < maximumTemperature ? new Temperature.F(minimumTemperature.toDouble()) : null,
      maximumTemperature: minimumTemperature < maximumTemperature ? new Temperature.F(maximumTemperature.toDouble()) : null,
      lastTemperature: finalCirculationTemperature > 0 ? new Temperature.F(finalCirculationTemperature.toDouble()) : null,
      minimumTurbidity: minimumTurbidity < maximumTurbidity ? new Turbidity.NTU(minimumTurbidity.toDouble()) : null,
      maximumTurbidity: minimumTurbidity < maximumTurbidity ? new Turbidity.NTU(maximumTurbidity.toDouble()) : null,
      startTime: new Duration(minutes: decodedData['cycleTime']),
      active: decodedData['cycleCompleted'] == 0,
      duration: new Duration(minutes: decodedData['cycleDurationInMinutes'])
    );
    dishwasher.setCycle(_cycle, cycleData);
  }
}

abstract class EnumHandler<T> extends MessageHandler {
  void parse(DateTime stamp, String data) {
    dynamic decodedData = JSON.decode(data);
    verify(decodedData is int);
    setValue(parseValue(decodedData));
  }

  T parseValue(int value);
  void setValue(T value);
}

class OperatingModeHandler extends EnumHandler<OperatingMode> {
  @override
  OperatingMode parseValue(int value) {
    switch (value) {
      case 0: return OperatingMode.lowPower;
      case 1: return OperatingMode.powerUp;
      case 2: return OperatingMode.standBy;
      case 3: return OperatingMode.delayStart;
      case 4: return OperatingMode.pause;
      case 5: return OperatingMode.active;
      case 6: return OperatingMode.endOfCycle;
      case 7: return OperatingMode.downloadMode;
      case 8: return OperatingMode.sensorCheckMode;
      case 9: return OperatingMode.loadActivationMode;
      case 11: return OperatingMode.invalidConnection;
      default: parseFail(); return null;
    }
  }

  @override
  void setValue(OperatingMode value) {
    dishwasher.operatingMode = value;
  }
}

class CycleStateHandler extends EnumHandler<CycleState> {
  @override
  CycleState parseValue(int value) {
    switch (value) {
      case 1: return CycleState.preWash;
      case 2: return CycleState.sensing;
      case 3: return CycleState.mainWash;
      case 4: return CycleState.drying;
      case 5: return CycleState.sanitizing;
      case 6: return CycleState.turbidityCalibration;
      case 7: return CycleState.diverterCalibration;
      case 8: return CycleState.pause;
      case 9: return CycleState.rinsing;
      case 10: return CycleState.cycleInactive;
      default: parseFail(); return null;
    }
  }

  @override
  void setValue(CycleState value) {
    dishwasher.cycleState = value;
  }
}

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

class ControlLockHandler extends EnumHandler<bool> {
  @override
  bool parseValue(int value) {
    switch (value) {
      case 0x55: return true;
      case 0xAA: return false;
      default: parseFail(); return null;
    }
  }

  @override
  void setValue(bool value) {
    dishwasher.controlLocked = value;
  }
}

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
