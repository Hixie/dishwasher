import 'dart:collection';

import 'box.dart';
import 'hash_utils.dart';
import 'collection_utils.dart';

enum DryOptions { idle, heated }
enum WashTemperature { normal, boost, sanitize }

enum DishwasherFeatures { heatedDry, boost, sanitize, washZones, steam, bottleBlast }
const Map<DishwasherFeatures, String> kDishwasherFeaturesDescriptions = const <DishwasherFeatures, String>{
  DishwasherFeatures.heatedDry: 'Heated dry',
  DishwasherFeatures.boost: 'Boost',
  DishwasherFeatures.sanitize: 'Sanitize',
  DishwasherFeatures.washZones: 'Wash zones',
  DishwasherFeatures.steam: 'Steam',
  DishwasherFeatures.bottleBlast: 'Bottle blast',
};

enum DishwasherReminders { cleanFilter, addRinseAid, sanitized }
const Map<DishwasherReminders, String> kDishwasherRemindersDescriptions = const <DishwasherReminders, String>{
  DishwasherReminders.cleanFilter: 'Clean filter',
  DishwasherReminders.addRinseAid: 'Add rinse aid',
  DishwasherReminders.sanitized: 'Sanitized',
};

enum UserCycleSelection { autosense, heavy, normal, light }
const Map<UserCycleSelection, String> kUserCycleSelectionDescriptions = const <UserCycleSelection, String>{
  UserCycleSelection.autosense: 'AutoSense',
  UserCycleSelection.heavy: 'Heavy',
  UserCycleSelection.normal: 'Normal',
  UserCycleSelection.light: 'Light',
};

enum OperatingMode { lowPower, powerUp, standBy, delayStart, pause, active, endOfCycle, downloadMode, sensorCheckMode, loadActivationMode, invalidConnection }
const Map<OperatingMode, String> kOperatingModeDescriptions = const <OperatingMode, String>{
  OperatingMode.lowPower: 'Low power',
  OperatingMode.powerUp: 'Power up',
  OperatingMode.standBy: 'Standby',
  OperatingMode.delayStart: 'Delay start',
  OperatingMode.pause: 'Paused',
  OperatingMode.active: 'Running',
  OperatingMode.endOfCycle: 'End of cycle',
  OperatingMode.downloadMode: 'Download mode',
  OperatingMode.sensorCheckMode: 'Sensor check mode',
  OperatingMode.loadActivationMode: 'Load activation mode',
  OperatingMode.invalidConnection: 'Invalid connection',
};

enum CycleSelection { none, autosense, heavy, normal, light }
const Map<CycleSelection, String> kCycleSelectionDescriptions = const <CycleSelection, String>{
  CycleSelection.none: 'no cycle selected',
  CycleSelection.autosense: 'autosense',
  CycleSelection.heavy: 'heavy',
  CycleSelection.normal: 'normal',
  CycleSelection.light: 'light',
};

enum CycleState { none, preWash, sensing, mainWash, drying, sanitizing, turbidityCalibration, diverterCalibration, pause, rinsing }
const Map<CycleState, String> kCycleStateDescriptions = const <CycleState, String>{
  CycleState.none: 'cycle inactive',
  CycleState.preWash: 'prewash',
  CycleState.sensing: 'sensing',
  CycleState.mainWash: 'main wash',
  CycleState.drying: 'drying',
  CycleState.sanitizing: 'sanitizing',
  CycleState.turbidityCalibration: 'calibrating turbidity sensors',
  CycleState.diverterCalibration: 'calibrating diverter',
  CycleState.pause: 'paused',
  CycleState.rinsing: 'rinsing',
};

const kCycle = 16;
const Map<int, String> kCycleStepDescriptions = const <int, String>{
  // seen only with autosense, steam, heated dry, and boost enabled
  (0 << kCycle) + 0: 'boost autosense program? prewash? 0:0',
  (0 << kCycle) + 1: 'boost autosense program? prewash? 0:1',
  (0 << kCycle) + 8: 'boost autosense program? main wash? 0:8',
  (0 << kCycle) + 9: 'boost autosense program? main wash? 0:9', // at this point, the soap was opened, though it didn't fall out. error 96 was reported.
  (0 << kCycle) + 10: 'boost autosense program? main wash? 0:10',
  (0 << kCycle) + 13: 'boost autosense program? rinsing? 0:13',
  (0 << kCycle) + 14: 'boost autosense program? rinsing? 0:14',
  
  // seen in autosense mode with Sanitize and Heated Dry together
  (2 << kCycle) + 0: 'autosense program? startup? 2:0', // 2ish minutes -> 2:1
  (2 << kCycle) + 1: 'autosense program 2:1', // 1ish minutes -> 21:0
  (2 << kCycle) + 7: 'autosense program 2:7', // -> 2:8
  (2 << kCycle) + 8: 'autosense program 2:8', // -> 2:9
  (2 << kCycle) + 9: 'autosense program 2:9', // long -> 2:9
  (2 << kCycle) + 10: 'autosense program 2:10', // -> 20:0-3 -> 27:0
  (2 << kCycle) + 14: 'autosense program 2:14', // -> 2:15
  (2 << kCycle) + 15: 'autosense program 2:15', // -> 20:0-3 -> 26:0
  
  // seen in heavy mode
  (3 << kCycle) + 0: 'heavy program? 3:0', // need to examine steps
  
  // seen in normal mode
  (6 << kCycle) + 1: 'normal program? prewash? silent? 6:1',
  (6 << kCycle) + 2: 'normal program? filling for prewash? 6:2',
  (6 << kCycle) + 8: 'normal program? main wash? silent? 6:8',
  (6 << kCycle) + 9: 'normal program? main wash, spinning? 6:9',
  (6 << kCycle) + 10: 'normal program? main wash, spinning and raising temperature? 6:10',
  (6 << kCycle) + 11: 'normal program? main wash, filling and spinning? 6:11',
  (6 << kCycle) + 15: 'normal program? rinsing? 6:15',
  (6 << kCycle) + 16: 'normal program? rinsing and reducing turbidity? 6:16',

  // seen in light mode
  (11 << kCycle) + 1: 'light program? startup?', // need to examine steps
  (11 << kCycle) + 13: 'light program, rinsing, spinning 11:13', // checked by opening mid-cycle
  
  (15 << kCycle) + 1: 'filling for prewash? 15:1',

  // only seen when steam is enabled
  (16 << kCycle) + 0: 'steam program? 16:0',
  (16 << kCycle) + 1: 'steam program? spinning water? 16:1',
  (16 << kCycle) + 3: 'steam program? 16:3',
  (16 << kCycle) + 4: 'steam program? spinning water? 16:4',

  (20 << kCycle) + 0: 'initialising draining cycle 20:0', // brief
  (20 << kCycle) + 1: 'draining 20:1',
  (20 << kCycle) + 2: 'twenty second delay during draining cycle 20:2',
  (20 << kCycle) + 3: 'draining until empty 20:3',

  (21 << kCycle) + 0: 'prewash for non-heavy cycles, spinning and raising temperature? 21:0', // 3ish minutes -> 20:0-3 -> 2:7

  // seen only with autosense, steam, heated dry, and boost enabled
  (22 << kCycle) + 0: 'boost autosense prewash? 22:0',
  (22 << kCycle) + 1: 'boost autosense prewash? 22:1',

  // seen only with normal program, sanitize enabled, rinse phase
  (23 << kCycle) + 0: 'sanitize rinse for normal program, adding water? 23:0',
  (23 << kCycle) + 1: 'sanitize rinse for normal program, adding more water? 23:1',

  (25 << kCycle) + 0: 'prewash for heavy program without steam 25:0',

  (26 << kCycle) + 0: 'sanitizing rinse 26:0', // long -> 75:1
  (26 << kCycle) + 1: 'sanitizing rinse 26:1', // ??? may not exist

  (27 << kCycle) + 0: 'autosense program, rinse phase 27:0', // -> 27:1
  (27 << kCycle) + 1: 'autosense program, rinse phase 27:1', // long -> 20:0-3 -> 2:14
  
  (35 << kCycle) + 0: 'heavy program, prewash 35:0',
  (37 << kCycle) + 0: 'heavy program, prewash 37:0',
  (39 << kCycle) + 0: 'heavy program, prewash 39:0',
  
  (52 << kCycle) + 0: 'heated dry starting', // -> 52:1
  (52 << kCycle) + 1: 'heated drying', // -> 52:2; goes inactive during this step
  (52 << kCycle) + 2: 'heated dry finished', // -> end; goes into standby when entering this step

  (56 << kCycle) + 0: 'non-sanitizing final phase 56:0',

  (59 << kCycle) + 0: 'filling for sanitization? 59:0', // long, -> 59:1
  (59 << kCycle) + 1: 'sanitizing, raising temperature? 59:1', // -> 59:2
  (59 << kCycle) + 2: 'sanitizing? 59:2', // starting at temp 68.3C? // -> 74:0-3 -> 52:0

  (63 << kCycle) + 4: 'idle standby with sanitize light? 63:4',

  (66 << kCycle) + 4: 'cycle finished', // -> end; not heated dry

  (71 << kCycle) + 0: 'second steam program? 71:0',

  (74 << kCycle) + 0: 'initialising final draining cycle 74:0',
  (74 << kCycle) + 1: 'final draining cycle 74:1',
  (74 << kCycle) + 2: 'twenty second delay during final draining cycle 74:2',
  (74 << kCycle) + 3: 'final draining cycle, draining until empty 74:3',

  (75 << kCycle) + 0: 'preinitialized draining cycle 75:1', // -> 75:2
  (75 << kCycle) + 1: 'twenty second delay during preinitialized draining cycle 75:2', // -> 75:3
  (75 << kCycle) + 2: 'preinitialized draining cycle, draining until empty 75:3', // -> 59:0
};

final Set<int> kUninterestingIdleCycleStates = new Set<int>.from(<int>[
  (66 << kCycle) + 4,
]);

String describeCycleStep(int cycleStep) {
  return kCycleStepDescriptions[cycleStep] ?? "${cycleStep >> kCycle}:${cycleStep & ~((~0) << kCycle)} ??";
}

String describeDuration(Duration duration) {
  String result = '';
  if (duration.inDays > 0) {
    result += '${duration.inDays}d ';
    duration -= new Duration(days: duration.inDays);
  }
  if (duration.inHours > 0 || result != '') {
    result += '${duration.inHours}h ';
    duration -= new Duration(hours: duration.inHours);
  }
  if (duration.inMinutes > 0 || result != '' || duration == Duration.ZERO) {
    result += '${duration.inMinutes}m';
    duration -= new Duration(minutes: duration.inMinutes);
  }
  if (duration.inSeconds > 0 || result == '') {
    if (result != '')
      result += ' ';
    result += '${duration.inSeconds}s';
  }
  return result;
}


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

  bool get justBegan {
    return minimumTemperature == null
        && maximumTemperature == null
        && lastTemperature == null
        && minimumTurbidity == null
        && maximumTurbidity == null
        && active
        && duration == Duration.ZERO;
  }

  String toString({ DateTime epoch, bool active: false }) {
    final List<String> result = <String>[];
    if (epoch == null)
      result.add('Start time offset: t₀+${describeDuration(startTime)}');
    else
      result.add('Start time: ${epoch.add(startTime).toLocal()}');
    if (number != 0)
      result.add('number $number');
    assert((minimumTemperature == null) == (maximumTemperature == null));
    assert((lastTemperature == null) || (minimumTemperature != null));
    if (minimumTemperature != null) {
      String temperatures = 'Temperature: $minimumTemperature .. $maximumTemperature';
      if (lastTemperature != null)
        temperatures += '; final: $lastTemperature';
      result.add(temperatures);
    }
    assert((minimumTurbidity == null) == (maximumTurbidity == null));
    if (minimumTurbidity != null)
      result.add('Turbidity: $minimumTurbidity .. $maximumTurbidity');
    if (active) {
      if (duration == Duration.ZERO)
        result.add('Just started...');
      else
        result.add('Duration: ${describeDuration(duration)} and counting...');
    } else {
      result.add('Duration: ${describeDuration(duration)}.');
    }
    return result.join('. ');
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

class DishwasherError {
  const DishwasherError({
    this.errorId,
    this.active
  });

  final int errorId;
  final bool active;

  String get errorMessage {
    switch (errorId) {
      // 96:
      //  - just after opening the dishwasher mid-rinse, water not drained, cycle canceled
      //  - just at the start of a main wash, when the soap didn't properly deploy
      // 99:
      //  - at the end of a wash cycle
      default: return '<code $errorId>.';
    }
  }

  String toString() {
    if (active)
      return 'ERROR: $errorMessage';
    return 'Last error: $errorMessage';
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! DishwasherError)
      return false;
    DishwasherError typedOther = other;
    return typedOther.errorId == errorId
        && typedOther.active == active;
  }

  @override
  int get hashCode => hashValues(
    errorId,
    active
  );
}

class NoDryDrainState {
  const NoDryDrainState({
    this.count,
    this.maximum
  });

  final int count;
  final int maximum;

  bool get alarmActive => count > 0;

  String toString() {
    if (count > 0)
      return 'FAILED DRY DRAIN DETECTED: $count (maximum $maximum).';
    return '$count failed dry drains (maximum $maximum).';
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! NoDryDrainState)
      return false;
    NoDryDrainState typedOther = other;
    return typedOther.count == count
        && typedOther.maximum == maximum;
  }

  @override
  int get hashCode => hashValues(
    count,
    maximum
  );
}

enum PersonalitySource { bootloaderParametric, AD }

class Personality {
  const Personality({
    this.boardId,
    this.source
  });

  final int boardId;
  final PersonalitySource source;

  String get boardDescription {
    switch (boardId) {
      case 15: return 'no UI personality installed';
      default: return '<unknown personality $boardId>';
    }
  }

  String get sourceDescription {
    switch (source) {
      case PersonalitySource.bootloaderParametric: return 'bootloader parametric';
      case PersonalitySource.AD: return 'A/D';
    }
    return '<unknown source $source>';
  }

  String toString() {
    return '$sourceDescription specified $boardDescription';
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! Personality)
      return false;
    Personality typedOther = other;
    return typedOther.boardId == boardId
        && typedOther.source == source;
  }

  @override
  int get hashCode => hashValues(
    boardId,
    source
  );
}

class DishwasherRates {
  const DishwasherRates({
    this.fill,
    this.drain
  });

  final int fill;
  final int drain;

  String toString() {
    return 'Fill rate: $fill. Drain rate: $drain.';
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! DishwasherRates)
      return false;
    DishwasherRates typedOther = other;
    return typedOther.fill == fill
        && typedOther.drain == drain;
  }

  @override
  int get hashCode => hashValues(
    fill,
    drain
  );
}

class ContinuousCycleState {
  const ContinuousCycleState({
    this.cycle,
    this.remainingCount,
    this.interval
  });

  final int cycle;
  final int remainingCount;
  final Duration interval;

  String toString() {
    return 'cycle $cycle, $remainingCount remaining cycles. ${describeDuration(interval)} between cycles.';
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! ContinuousCycleState)
      return false;
    ContinuousCycleState typedOther = other;
    return typedOther.cycle == cycle
        && typedOther.remainingCount == remainingCount
        && typedOther.interval == interval;
  }

  @override
  int get hashCode => hashValues(
    cycle,
    remainingCount,
    interval
  );
}

typedef void CycleTransitionHandler(int step, Duration time, CycleData currentData);
typedef void PrintHandler(String message);

// DISHWASHER
// ==========

class Dishwasher {
  bool _dirtyUI = false;
  bool _dirtyLog = false;
  bool _dirtyInternals = false;

  DateTime get lastMessageTimestamp => _lastMessageTimestamp;
  DateTime _lastMessageTimestamp;
  set lastMessageTimestamp(DateTime value) {
    if (_lastMessageTimestamp == value)
      return;
    _lastMessageTimestamp = value;
  }

  OperatingMode get operatingMode => _operatingMode;
  OperatingMode _operatingMode;
  set operatingMode(OperatingMode value) {
    if (_operatingMode == value)
      return;
    _operatingMode = value;
    _dirtyUI = true;
  }

  CycleSelection get cycleSelection => _cycleSelection;
  CycleSelection _cycleSelection;
  set cycleSelection(CycleSelection value) {
    if (_cycleSelection == value)
      return;
    _cycleSelection = value;
    _dirtyUI = true;
  }

  CycleState get cycleState => _cycleState;
  CycleState _cycleState;
  set cycleState(CycleState value) {
    if (_cycleState == value)
      return;
    _cycleState = value;
    _dirtyUI = true;
  }

  Stopwatch _cycleTimer = new Stopwatch();

  int get cycleStep => _cycleStep;
  int _cycleStep = 0;
  set cycleStep(int value) {
    if (_cycleStep == value)
      return;
    if (_cycleTimer.isRunning)
      cycleTransition(cycleStep, _cycleTimer.elapsed);
    _cycleTimer.reset();
    _cycleTimer.start();
    _cycleStep = value;
    _dirtyUI = true;
  }

  CycleTransitionHandler onCycleTransition;

  void cycleTransition(int step, Duration time) {
    if (onCycleTransition != null)
      onCycleTransition(step, time, _activeCycle);
    else
      notify('Cycle step transition. Ran step "${describeCycleStep(cycleStep)}" for ${describeDuration(_cycleTimer.elapsed)}.');
  }

  int get stepsExecuted => _stepsExecuted;
  int _stepsExecuted = 0;
  set stepsExecuted(int value) {
    if (_stepsExecuted == value)
      return;
    _stepsExecuted = value;
    _dirtyUI = true;
  }

  int get stepsEstimated => _stepsEstimated;
  int _stepsEstimated = 0;
  set stepsEstimated(int value) {
    if (_stepsEstimated == value)
      return;
    _stepsEstimated = value;
    _dirtyUI = true;
  }

  int get countOfCyclesStarted => _countOfCyclesStarted;
  int _countOfCyclesStarted;
  set countOfCyclesStarted(int value) {
    if (_countOfCyclesStarted == value)
      return;
    _countOfCyclesStarted = value;
    _dirtyUI = true;
  }

  int get countOfCyclesCompleted => _countOfCyclesCompleted;
  int _countOfCyclesCompleted;
  set countOfCyclesCompleted(int value) {
    if (_countOfCyclesCompleted == value)
      return;
    _countOfCyclesCompleted = value;
    _dirtyUI = true;
  }

  int get countOfCyclesReset => _countOfCyclesReset;
  int _countOfCyclesReset;
  set countOfCyclesReset(int value) {
    if (_countOfCyclesReset == value)
      return;
    _countOfCyclesReset = value;
    _dirtyUI = true;
  }

  WashTemperature get washTemperature => _washTemperature;
  WashTemperature _washTemperature = WashTemperature.normal;
  set washTemperature(WashTemperature value) {
    if (_washTemperature == value)
      return;
    _washTemperature = value;
    _dirtyUI = true;
  }

  UserCycleSelection get userCycleSelection => _userCycleSelection;
  UserCycleSelection _userCycleSelection = UserCycleSelection.autosense;
  set userCycleSelection(UserCycleSelection value) {
    if (_userCycleSelection == value)
      return;
    _userCycleSelection = value;
    _dirtyUI = true;
  }

  int get delay => _delay;
  int _delay = 0;
  set delay(int value) {
    if (_delay == value)
      return;
    _delay = value;
    _dirtyUI = true;
  }

  bool get sabbathMode => _sabbathMode;
  bool _sabbathMode = false;
  set sabbathMode(bool value) {
    if (_sabbathMode == value)
      return;
    _sabbathMode = value;
    _dirtyUI = true;
  }

  bool get uiLocked => _uiLocked;
  bool _uiLocked = false;
  set uiLocked(bool value) {
    if (_uiLocked == value)
      return;
    _uiLocked = value;
    _dirtyUI = true;
  }

  bool get controlLocked => _controlLocked;
  bool _controlLocked = false;
  set controlLocked(bool value) {
    if (_controlLocked == value)
      return;
    _controlLocked = value;
    _dirtyUI = true;
  }

  bool get demo => _demo;
  bool _demo = false;
  set demo(bool value) {
    if (_demo == value)
      return;
    _demo = value;
    _dirtyUI = true;
  }

  bool get mute => _mute;
  bool _mute = false;
  set mute(bool value) {
    if (_mute == value)
      return;
    _mute = value;
    _dirtyUI = true;
  }

  bool get steam => _steam;
  bool _steam = false;
  set steam(bool value) {
    if (_steam == value)
      return;
    _steam = value;
    _dirtyUI = true;
  }

  DryOptions get dryOptions => _dryOptions;
  DryOptions _dryOptions = DryOptions.idle;
  set dryOptions(DryOptions value) {
    if (_dryOptions == value)
      return;
    _dryOptions = value;
    _dirtyUI = true;
  }

  bool get rinseAidEnabled => _rinseAidEnabled;
  bool _rinseAidEnabled = false;
  set rinseAidEnabled(bool value) {
    if (_rinseAidEnabled == value)
      return;
    _rinseAidEnabled = value;
    _dirtyUI = true;
  }

  Set<DishwasherReminders> get reminders => new HashSet<DishwasherReminders>.from(_reminders);
  Set<DishwasherReminders> _reminders = new HashSet<DishwasherReminders>();
  set reminders(Set<DishwasherReminders> value) {
    final Set<DishwasherReminders> newValue = new HashSet<DishwasherReminders>.from(value);
    if (setsEqual/*<DishwasherReminders>*/(_reminders, newValue))
      return;
    _reminders = newValue;
    _dirtyUI = true;
  }

  Set<DishwasherFeatures> get disabledFeatures => new HashSet<DishwasherFeatures>.from(_disabledFeatures);
  Set<DishwasherFeatures> _disabledFeatures = new HashSet<DishwasherFeatures>();
  set disabledFeatures(Set<DishwasherFeatures> value) {
    final Set<DishwasherFeatures> newValue = new HashSet<DishwasherFeatures>.from(value);
    if (setsEqual/*<DishwasherFeatures>*/(_disabledFeatures, newValue))
      return;
    _disabledFeatures = newValue;
    _dirtyInternals = true;
  }

  int get doorCount => _doorCount;
  int _doorCount;
  set doorCount(int value) {
    if (_doorCount == value)
      return;
    _doorCount = value;
    _dirtyUI = true;
  }

  List<int> get sensors => _sensors.toList();
  List<int> _sensors;
  set sensors(Iterable<int> value) {
    final List<int> newValue = value.toList();
    if (listsEqual/*<int>*/(_sensors, newValue))
      return;
    _sensors = newValue;
    _dirtyUI = true;
  }

  static const List<String> kSensorBlocks = const <String>[ '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' ];

  String graphSensors(List<int> value) {
    if (value == null)
      return '';
    String result = '';
    for (int index = 0; index < value.length; index += 1)
      result += kSensorBlocks[value[index] ~/ (256.0 / kSensorBlocks.length)];
    return result;
  }

  DishwasherError get errorState => _errorState;
  DishwasherError _errorState;
  set errorState(DishwasherError value) {
    if (_errorState == value)
      return;
    _errorState = value;
    _dirtyInternals = true;
  }

  NoDryDrainState get noDryDrainState => _noDryDrainState;
  NoDryDrainState _noDryDrainState;
  set noDryDrainState(NoDryDrainState value) {
    if (_noDryDrainState == value)
      return;
    _noDryDrainState = value;
    _dirtyInternals = true;
  }

  Personality get personality => _personality;
  Personality _personality;
  set personality(Personality value) {
    if (_personality == value)
      return;
    _personality = value;
    _dirtyInternals = true;
  }

  ContinuousCycleState get continuousCycleState => _continuousCycleState;
  ContinuousCycleState _continuousCycleState;
  set continuousCycleState(ContinuousCycleState value) {
    if (_continuousCycleState == value)
      return;
    _continuousCycleState = value;
    _dirtyInternals = true;
  }

  DishwasherRates get rates => _rates;
  DishwasherRates _rates;
  set rates(DishwasherRates value) {
    if (_rates == value)
      return;
    _rates = value;
    _dirtyInternals = true;
  }

  final Set<CycleData> _cycles = new Set<CycleData>();
  CycleData _activeCycle;
  int _lastActiveCycleIndex;
  void setCycle(int cycle, CycleData data, DateTime stamp) {
    assert(cycle >= 0 && cycle < _cycles.length);
    assert(data != null);
    if (data.active && !isIdle && (_activeCycle == null || (_activeCycle.startTime <= data.startTime))) {
      assert(_lastActiveCycleIndex == null || cycle == _lastActiveCycleIndex);
      if (_activeCycle == null) {
        if (data.justBegan)
          epoch = stamp.subtract(data.startTime);
      }
      _activeCycle = data;
      _lastActiveCycleIndex = cycle;
      if (data != _activeCycle)
        _dirtyUI = true;
    } else {
      if (cycle == _lastActiveCycleIndex) {
        assert(data.startTime == _activeCycle.startTime);
        _activeCycle = null;
        _lastActiveCycleIndex = null;
      }
      if (_cycles.add(data))
        _dirtyLog = true;
    }
  }

  DateTime get epoch => _epoch;
  DateTime _epoch;
  set epoch(DateTime value) {
    if (_epoch == value)
      return;
    _epoch = value;
    notifyEpochEstablished();
    if (_activeCycle != null)
      _dirtyUI = true;
    if (_cycles.isNotEmpty)
      _dirtyLog = true;
  }

  void notifyEpochEstablished() {
    // TODO(ianh): Make a note when the epoch is being _re_established to a different value
    notify('Dishwasher epoch established: ${epoch.toLocal()}');
  }

  bool get isRunning => operatingMode == OperatingMode.active;
  bool get isPaused => operatingMode == OperatingMode.pause;
  bool get isIdle => !isRunning && !isPaused;

  static final _uiBox = new SingleLineBox();
  void printInterface() {
    List<String> settings = <String>[];
    if (delay > 0)
      settings.add('Delay Hours: ${delay}h');
    settings.add(kUserCycleSelectionDescriptions[userCycleSelection] ?? 'UNKNOWN CYCLE SELECTION');
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
    // CURRENT OPERATING MODE AND CYCLE STATE
    // * Operating mode
    final String operatingModeDescription = kOperatingModeDescriptions[operatingMode] ?? 'Unknown operating mode';
    assert(isIdle || isRunning || isPaused);
    // * Cycle selection
    final String cycleSelectionDescription = kCycleSelectionDescriptions[cycleSelection] ?? 'Unknown cycle selection';
    // * Cycle state
    final String cycleStateDescription = kCycleStateDescriptions[cycleState] ?? 'unknown cycle state';
    // * Cycle Phase
    final String cycleStepDescription = describeCycleStep(cycleStep);
    // BOX
    String modeUI;
    if (isIdle) {
      if (cycleState != CycleState.none) {
        modeUI = 'INCONSISTENT STATE • $operatingModeDescription • $cycleSelectionDescription • $cycleStateDescription • $cycleStepDescription';
      } else if (!kUninterestingIdleCycleStates.contains(cycleStep)) {
        //if (cycleSelection != CycleSelection.none) {
        //  modeUI = '$operatingModeDescription • last cycle selection: $cycleSelectionDescription • $cycleStepDescription';
        //} else {
          modeUI = '$operatingModeDescription • $cycleStepDescription';
        //}
      } else {
        modeUI = '$operatingModeDescription';
      }
    } else if (isPaused) {
      if (cycleSelection == CycleSelection.none || cycleState != CycleState.pause) {
        modeUI = 'INCONSISTENT STATE • $operatingModeDescription • $cycleSelectionDescription • $cycleStateDescription • $cycleStepDescription';
      } else {
        modeUI = 'PAUSED • $cycleSelectionDescription • $cycleStepDescription';
      }
    } else {
      if (cycleSelection == CycleSelection.none || cycleState == CycleState.none || kUninterestingIdleCycleStates.contains(cycleStep)) {
        modeUI = 'INCONSISTENT STATE • $operatingModeDescription • $cycleSelectionDescription • $cycleStateDescription • $cycleStepDescription';
      } else {
        modeUI = '$operatingModeDescription • $cycleSelectionDescription • $cycleStateDescription • $cycleStepDescription';
      }
    }
    final List<String> topLeft = <String>[modeUI];
    if (reminders.contains(DishwasherReminders.sanitized))
      topLeft.add('SANITIZED');
    if (demo)
      topLeft.add('DEMO');
    final List<String> topRight = <String>[];
    if (mute)
      topRight.add('MUTED');
    if (reminders.contains(DishwasherReminders.addRinseAid))
      topRight.add('ADD RINSE AID');
    if (reminders.contains(DishwasherReminders.cleanFilter))
      topRight.add('CLEAN FILTER');
    final List<String> bottomCenter = <String>[];
    if (_lastMessageTimestamp != null)
      bottomCenter.add('${_lastMessageTimestamp.toLocal()}');
    final List<String> contents = <String>[settings.join("  ")];
    if (!isIdle)
      contents.add('Progress: ${ "█" * stepsExecuted }${ "░" * (stepsEstimated - stepsExecuted) } ${(100.0 * stepsExecuted / stepsEstimated).toStringAsFixed(1)}% ($stepsExecuted/$stepsEstimated)');
    if (_activeCycle != null)
      contents.add(_activeCycle.toString(epoch: epoch, active: true));
    assert((_countOfCyclesStarted == null) == (_countOfCyclesCompleted == null));
    assert((_countOfCyclesStarted == null) == (_countOfCyclesReset == null));
    if (_countOfCyclesStarted != null)
      contents.add('Cycle counts: $_countOfCyclesStarted started, $_countOfCyclesCompleted completed, $_countOfCyclesReset reset');
    contents.add('Door open/close count: ${ doorCount ?? "unknown" } \t Sensors: ${ graphSensors(_sensors) }');
    writeln(_uiBox.buildBox(
      topLeftLabels: topLeft,
      topRightLabels: topRight,
      bottomCenterLabels: bottomCenter,
      lines: contents,
      margin: 3,
      padding: 1
    ));
    writeln('');
  }

  static final _internalsBox = new DoubleLineBox();
  void printInternals() {
    final List<String> lines = <String>[];
    if (personality != null)
      lines.add('Personality: $personality.');
    if (disabledFeatures.length > 0) {
      final List<String> disabledFeaturesDescriptions = disabledFeatures.map/*<String>*/((DishwasherFeatures feature) => kDishwasherFeaturesDescriptions[feature]).toList();
      disabledFeaturesDescriptions.sort();
      lines.add('Disabled features: ${disabledFeaturesDescriptions.join(", ")}.');
    }
    if (rates != null)
      lines.add('$rates');
    if (errorState != null)
      lines.add('$errorState');
    if (noDryDrainState != null)
      lines.add('Dry drain state: $noDryDrainState');
    if (continuousCycleState != null)
      lines.add('Continuous cycle mode: $continuousCycleState');
    if (controlLocked == true)
      lines.add('Control Locks: Locked (?)');
    writeln(_internalsBox.buildBox(
      lines: lines
    ));
    writeln('');
  }

  void printLog() {
    final List<CycleData> cycles = _cycles.toList();
    cycles.sort((CycleData a, CycleData b) => (b.startTime).compareTo(a.startTime));
    writeln('Completed cycle log (most recent first):');
    int index = cycles.length;
    for (CycleData cycle in cycles) {
      writeln('${index.toString().padLeft(7)}: ${cycle.toString(epoch: epoch)}');
      index -= 1;
    }
    writeln('');
  }

  bool enableNotifications = false;

  void notify(String s) {
    if (enableNotifications)
      writeln('$s\n');
  }

  bool get isDirty => _dirtyInternals || _dirtyUI || _dirtyLog;

  PrintHandler onPrint;
  void writeln(String message) {
    if (onPrint != null)
      onPrint(message);
  }

  void printUpdates() {
    if (_dirtyInternals) {
      printInternals();
      _dirtyInternals = false;
    }
    if (_dirtyUI) {
      printInterface();
      _dirtyUI = false;
    }
    if (_dirtyLog) {
      printLog();
      _dirtyLog = false;
    }
  }

  void printEverything() {
    printInternals();
    _dirtyInternals = false;
    printInterface();
    _dirtyUI = false;
    printLog();
    _dirtyLog = false;
  }
}
