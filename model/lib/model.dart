import 'utils.dart';

enum DryOptions { idle, heated }
enum WashTemperature { normal, boost, sanitize }
enum UserCycleSelection { autosense, heavy, normal, light }
enum OperatingMode { lowPower, powerUp, standBy, delayStart, pause, active, endOfCycle, downloadMode, sensorCheckMode, loadActivationMode, invalidConnection }
enum CycleState { preWash, sensing, mainWash, drying, sanitizing, turbidityCalibration, diverterCalibration, pause, rinsing, cycleInactive }

class Temperature {
  const Temperature.F(this.fahrenheit);
  const Temperature.C(double celsius) : fahrenheit = celsius * 1.8 + 32.0;

  final double fahrenheit;
  double get celsius => (fahrenheit - 32.0) / 1.8;

  bool operator <(Temperature other) => fahrenheit < other.fahrenheit;
  bool operator <=(Temperature other) => fahrenheit <= other.fahrenheit;
  bool operator >(Temperature other) => fahrenheit > other.fahrenheit;
  bool operator >=(Temperature other) => fahrenheit >= other.fahrenheit;

  @override
  String toString() => '${celsius.toStringAsFixed(1)}°C';

  @override
  bool operator ==(dynamic other) {
    if (other is! Temperature)
      return false;
    Temperature typedOther = other;
    return typedOther.fahrenheit == fahrenheit;
  }

  @override
  int get hashCode => fahrenheit.hashCode;
}

class Turbidity {
  const Turbidity.NTU(this.ntu);

  final double ntu; // Nephelometric Turbidity Units

  bool operator <(Turbidity other) => ntu < other.ntu;
  bool operator <=(Turbidity other) => ntu <= other.ntu;
  bool operator >(Turbidity other) => ntu > other.ntu;
  bool operator >=(Turbidity other) => ntu >= other.ntu;

  @override
  String toString() => '${ntu.toStringAsFixed(1)} NTU';

  @override
  bool operator ==(dynamic other) {
    if (other is! Turbidity)
      return false;
    Turbidity typedOther = other;
    return typedOther.ntu == ntu;
  }

  @override
  int get hashCode => ntu.hashCode;
}

class CycleData {
  const CycleData({
    this.number,
    this.minimumTemperature,
    this.maximumTemperature,
    this.lastTemperature,
    this.minimumTurbidity,
    this.maximumTurbidity,
    this.startTime,
    this.active,
    this.duration
  });

  final int number;
  final Temperature minimumTemperature;
  final Temperature maximumTemperature;
  final Temperature lastTemperature;
  final Turbidity minimumTurbidity;
  final Turbidity maximumTurbidity;
  final Duration startTime; // relative to some unclear epoch
  final bool active;
  final Duration duration;

  String toString() {
    final List<String> result = <String>[];
    if (number != 0)
      result.add('number $number');
    assert((minimumTemperature == null) == (maximumTemperature == null));
    assert((lastTemperature == null) || (minimumTemperature != null));
    if (minimumTemperature != null) {
      String temperatures = 'Temperature: $minimumTemperature .. $maximumTemperature';
      if (lastTemperature != null)
        temperatures += ' (Final: $lastTemperature)';
      result.add(temperatures);
    }
    assert((minimumTurbidity == null) == (maximumTurbidity == null));
    if (minimumTurbidity != null)
      result.add('Turbidity: $minimumTurbidity .. $maximumTurbidity');
    result.add('start time offset: $startTime');
    String lead;
    if (active) {
      lead = 'Active:';
      result.add('Duration: $duration and counting...');
    } else {
      lead = 'Completed:';
      result.add('Duration: $duration');
    }
    return '$lead ${result.join("; ")}';
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! CycleData)
      return false;
    CycleData typedOther = other;
    return typedOther.number == number
        && typedOther.minimumTemperature == minimumTemperature
        && typedOther.maximumTemperature == maximumTemperature
        && typedOther.lastTemperature == lastTemperature
        && typedOther.minimumTurbidity == minimumTurbidity
        && typedOther.maximumTurbidity == maximumTurbidity
        && typedOther.startTime == startTime
        && typedOther.active == active
        && typedOther.duration == duration;
  }

  @override
  int get hashCode => hashValues(
    number,
    minimumTemperature,
    maximumTemperature,
    lastTemperature,
    minimumTurbidity,
    maximumTurbidity,
    startTime,
    active,
    duration
  );
}

class Dishwasher {
  bool _dirty = false;

  OperatingMode get operatingMode => _operatingMode;
  OperatingMode _operatingMode;
  set operatingMode(OperatingMode value) {
    if (_operatingMode == value)
      return;
    _operatingMode = value;
    _dirty = true;
  }

  CycleState get cycleState => _cycleState;
  CycleState _cycleState;
  set cycleState(CycleState value) {
    if (_cycleState == value)
      return;
    _cycleState = value;
    _dirty = true;
  }

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

  bool get controlLocked => _controlLocked;
  bool _controlLocked = false;
  set controlLocked(bool value) {
    if (_controlLocked == value)
      return;
    _controlLocked = value;
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

  void printInterface() {
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
      settings.add('Controls Locked');
    if (sabbathMode)
      settings.add('Sabbath Mode');
    String operatingModeDescription = 'Unknown operating mode';
    switch (operatingMode) {
      case OperatingMode.lowPower: operatingModeDescription = 'Low power'; break;
      case OperatingMode.powerUp: operatingModeDescription = 'Power up'; break;
      case OperatingMode.standBy: operatingModeDescription = 'Standby'; break;
      case OperatingMode.delayStart: operatingModeDescription = 'Delay start'; break;
      case OperatingMode.pause: operatingModeDescription = 'Paused'; break;
      case OperatingMode.active: operatingModeDescription = 'Active'; break;
      case OperatingMode.endOfCycle: operatingModeDescription = 'End of cycle'; break;
      case OperatingMode.downloadMode: operatingModeDescription = 'Download mode'; break;
      case OperatingMode.sensorCheckMode: operatingModeDescription = 'Sensor check mode'; break;
      case OperatingMode.loadActivationMode: operatingModeDescription = 'Load activation mode'; break;
      case OperatingMode.invalidConnection: operatingModeDescription = 'Invalid connection'; break;
    }
    String cycleStateDescription = 'unknown cycle state';
    bool expectedCycleState = false;
    bool redundantCycleState = false;
    switch (cycleState) {
      case CycleState.preWash: cycleStateDescription = 'prewash'; expectedCycleState = operatingMode == OperatingMode.active; break;
      case CycleState.sensing: cycleStateDescription = 'sensing'; expectedCycleState = operatingMode == OperatingMode.active; break;
      case CycleState.mainWash: cycleStateDescription = 'main wash'; expectedCycleState = operatingMode == OperatingMode.active; break;
      case CycleState.drying: cycleStateDescription = 'drying'; expectedCycleState = operatingMode == OperatingMode.active; break;
      case CycleState.sanitizing: cycleStateDescription = 'sanitizing'; expectedCycleState = operatingMode == OperatingMode.active; break;
      case CycleState.turbidityCalibration: cycleStateDescription = 'calibrating turbidity sensors'; expectedCycleState = operatingMode == OperatingMode.active; break;
      case CycleState.diverterCalibration: cycleStateDescription = 'calibrating diverter'; expectedCycleState = operatingMode == OperatingMode.active; break;
      case CycleState.pause: cycleStateDescription = 'paused'; expectedCycleState = operatingMode == OperatingMode.pause; redundantCycleState = true; break;
      case CycleState.rinsing: cycleStateDescription = 'rinsing'; expectedCycleState = operatingMode == OperatingMode.active; break;
      case CycleState.cycleInactive: cycleStateDescription = 'cycle inactive'; expectedCycleState = operatingMode != OperatingMode.active && operatingMode != OperatingMode.pause; redundantCycleState = true; break;
    }
    String modeUI;
    if (expectedCycleState) {
      if (redundantCycleState) {
        modeUI = '┤ $operatingModeDescription ├';
      } else {
        modeUI = '┤ $operatingModeDescription • $cycleStateDescription ├';
      }
    } else {
      modeUI = '┤ $operatingModeDescription • $cycleStateDescription (!!) ├';
    }
    String demoUI = demo ? '┤ DEMO ├' : '';
    String muteUI = mute ? '┤ MUTED ├' : '';
    int margin = 5;
    final String buttons = '│ ${ settings.join("  ").padRight(margin * 4 + modeUI.length + demoUI.length + muteUI.length) } │';
    String leaderLeft = '┌${"─" * margin}$modeUI${"─" * margin}$demoUI';
    String leaderRight = '$muteUI${"─" * margin}┐';
    int innerWidth = buttons.length - leaderLeft.length - leaderRight.length;
    String leader = '$leaderLeft${ "─" * innerWidth }$leaderRight';
    String footer = '└${ "─" * (leader.length - 2) }┘';
    print(leader);
    print(buttons);
    print(footer);
    if (controlLocked == true)
      settings.add('Control Locks: Locked (?)');
  }

  CycleData _cycle0;
  CycleData _cycle1;
  CycleData _cycle2;
  CycleData _cycle3;
  CycleData _cycle4;
  void setCycle(int cycle, CycleData data) {
    assert(cycle >= 0 && cycle <= 4);
    assert(data != null);
    CycleData oldCycle;
    switch (cycle) {
      case 0: oldCycle = _cycle0; _cycle0 = data; break;
      case 1: oldCycle = _cycle1; _cycle1 = data; break;
      case 2: oldCycle = _cycle2; _cycle2 = data; break;
      case 3: oldCycle = _cycle3; _cycle3 = data; break;
      case 4: oldCycle = _cycle4; _cycle4 = data; break;
    }
    if (oldCycle != data)
      _dirty = true;
  }

  void printCycles() {
    final List<CycleData> cycles = <CycleData>[
      _cycle0,
      _cycle1,
      _cycle2,
      _cycle3,
      _cycle4,
    ];
    cycles.sort((CycleData a, CycleData b) => (a?.startTime ?? Duration.ZERO).compareTo(b?.startTime ?? Duration.ZERO));
    print('Cycle Log:');
    for (CycleData cycle in cycles)
      print('  $cycle');
  }

  void checkDirty() {
    if (_dirty) {
      printInterface();
      printCycles();
      _dirty = false;
    }
  }
}

final Dishwasher dishwasher = new Dishwasher();
