// This has only been tested with a GE GDF570SGFWW dishwasher

// This is a stand-alone script that provides a little interface to
// the dishwasher. It tries to interpret messages and print them.

require('events').EventEmitter.prototype._maxListeners = 0;

const dishwasherEpoch = 1462569778000;
const delayTime = 500;
const timeoutTime = 10000;
const keepAliveTime = -2000; // negative means disabled

const greenBean = require("green-bean");
const readline = require('readline');
const rl = readline.createInterface(process.stdin, process.stdout);
rl.setPrompt('dishwasher> ');

var pendingCount = 1;

function log(s) {
  var date = new Date();
  var year = date.getFullYear();
  var month = pad((date.getMonth() + 1).toString(), '00');
  var day = pad((date.getDate()).toString(), '00');
  var hour = pad(date.getHours().toString(), '00');
  var minute = pad(date.getMinutes().toString(), '00');
  var second = pad(date.getSeconds().toString(), '00');
  var timestamp = ''+ year + '-' + month + '-' + day + ' ' + hour + ':' + minute + ':' + second;
  console.log(timestamp + '| ' + s);
}

function describe(data) {
  if (typeof data == 'number') {
    if (data != 0)
      return '' + data + ' (0x' + data.toString(16) + ', 0b' + data.toString(2) + ')';
    return 'nil';
  } else if (typeof data == 'string') {
    return '"' + data + '"';
  } else if (Array.isArray(data)) {
    return '[' + data.map(describe).join(', ') + ']';
  } else if (typeof data == 'object') {
    var s = '';
    for (var f in data) {
      if (s != '')
        s += '; ';
      s += f + '=' + describe(data[f]);
    }
    return '{ ' + s + ' }';
  } else {
    return '' + data + ' (' + typeof data + ')';
  }
}

function report(name, data) {
  if (pendingCount == 0)
    log('');
  log(name + ': ' + describe(data));
  if (pendingCount == 0)
    rl.prompt(true);
}

function describeCycleStatus(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    var result = [];
    switch (data.cycleRunning) {
      case 0: result.push('inactive'); break;
      case 1: result.push('autosense'); break;
      case 3: result.push('heavy'); break;
      case 6: result.push('normal'); break;
      case 11: result.push('light'); break;
      default: result.push('cycleRunning=' + data.cycleRunning);
    }
    result.push('activeCycle=' + data.activeCycle);
    result.push('activeCycleStep=' + data.activeCycleStep);
    if (data.stepsEstimated >= data.stepsExecuted)
      result.push('[' + ('#'.repeat(data.stepsExecuted)) + ('.'.repeat(data.stepsEstimated - data.stepsExecuted)) + ']');
    result.push('' + data.stepsExecuted + '/' + data.stepsEstimated + ' steps');
    return result.join(', ');
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportCycleStatus(name, data) {
  log(name + ': ' + describeCycleStatus(data));
}

function describeCycleCounts(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    var result = [];
    result.push('completed ' + data.completedCount + ' of ' + data.startedCount + ' cycles');
    result.push('reset ' + data.resetCount + ' cycles');
    return result.join(', ');
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportCycleCounts(name, data) {
  log(name + ': ' + describeCycleCounts(data));
}

function describeRates(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    var result = [];
    result.push('fillRate=' + data.fillRate);
    result.push('drainRate=' + data.drainRate);
    return result.join(', ');
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportRates(name, data) {
  log(name + ': ' + describeRates(data));
}

function describeDryDrainCounters(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    var result = [];
    result.push('dry drain failed ' + data.noDryDrainDetectedCount + ' times');
    result.push('limit: ' + data.noDryDrainDetectedMaximumValue);
    return result.join(', ');
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportDryDrainCounters(name, data) {
  log(name + ': ' + describeDryDrainCounters(data));
}

function describeAnalogData(data) {
  if (!Array.isArray(data))
    return '<unexpected format: ' + describe(data) + '>';
  var s = '';
  for (var index = 0; index < data.length; index += 1) {
    var octet = data[index];
    if (octet == 0x00)
      s += ' ..';
    else if (octet < 0x10)
      s += ' 0' + octet.toString(16);
    else
      s += ' ' + octet.toString(16);
  }
  return s;
}

function reportAnalogData(name, data) {
  log(name + ': ' + describeAnalogData(data));
}

function describeOperatingMode(data) {
  if (typeof data != 'number')
    return '<unexpected format: ' + describe(data) + '>';
  switch (data) {
    case 0: return 'Low Power';
    case 1: return 'Power Up';
    case 2: return 'Standby';
    case 3: return 'Delay Start';
    case 4: return 'Pause';
    case 5: return 'Cycle Active';
    case 6: return 'End of Cycle';
    case 7: return 'Download Mode';
    case 8: return 'Sensor Check Mode';
    case 9: return 'Load Activation Mode';
    case 11: return '11 (try restarting, this usually indicates an invalid connection)'; // see https://github.com/GEMakers/gea-plugin-dishwasher/issues/4
    default: return '<unknown: ' + describe(data) + '>';
  }
}

function reportOperatingMode(name, data) {
  log(name + ': ' + describeOperatingMode(data));
}

function describeDisabledFeatures(data) {
  if (typeof data != 'number')
    return '<unexpected format: ' + describe(data) + '>';
  var result = [];
  if (data & 0x01) // bit 0
    result.push('Heated Dry');
  if (data & 0x02) // bit 1
    result.push('Boost');
  if (data & 0x04) // bit 2
    result.push('Sanitize');
  if (data & 0x08) // bit 3
    result.push('Wash Zones');
  if (data & 0x10) // bit 4
    result.push('Steam');
  if (data & 0x20) // bit 5
    result.push('Bottle Blast');
  data >>= 6;
  index = 6;
  while (data) {
    if (data & 0x01)
      result.push('<unknown feature with bit ' + index +'>');
    data >>= 1;
    index += 1;
  }
  if (result.length == 0)
    return 'all features enabled';
  return result.join(', ');
}

function reportDisabledFeatures(name, data) {
  log(name + ': ' + describeDisabledFeatures(data));
}

function describeReminders(data) {
  if (typeof data != 'number')
    return '<unexpected format: ' + describe(data) + '>';
  var result = [];
  if (data & 0x01) // bit 0
    result.push('Clean Filter');
  if (data & 0x02) // bit 1
    result.push('Add Rinse Aid');
  if (data & 0x04) // bit 2
    result.push('Sanitized');
  data >>= 3;
  index = 3;
  while (data) {
    if (data & 0x01)
      result.push('<unknown reminder with bit ' + index +'>');
    data >>= 1;
    index += 1;
  }
  if (result.length == 0)
    return 'no reminders';
  return result.join(', ');
}

function reportReminders(name, data) {
  log(name + ': ' + describeReminders(data));
}

function describeUserConfiguration(data) {
  if (!Array.isArray(data) || data.length != 3)
    return '<unexpected format: ' + describe(data) + '>';
  var result = [];
  switch (data[0] & 0x0F) {
    case 0: break; // no delay start
    case 1: result.push('Delay Start: 2h'); break;
    case 2: result.push('Delay Start: 4h'); break;
    case 3: result.push('Delay Start: 8h'); break;
  }
  if (data[0] & 0x30)
    result.push('Zone: ' + ((data[0] & 0x30) >> 4));
  if (data[0] & 0x40)
    result.push('Demo Mode');
  if (data[0] & 0x80)
    result.push('Mute'); // press Heated Dry five (?) times in a row to toggle
  if (data[1] & 0x01)
    result.push('Steam');
  if (data[1] & 0x02)
    result.push('UI Locked');
  var dryOptions = ((data[1] & 0x0C) >> 2);
  switch (dryOptions) {
    case 0: result.push('Dry Options: Idle Dry'); break;
    case 1: result.push('Dry Options: Heated Dry'); break;
    default: result.push('Dry Options <unknown value ' + dryOptions + '>'); break;
  }
  var washTemp = ((data[1] & 0x70) >> 4);
  switch (washTemp) {
    case 0: result.push('Wash Temp: Normal'); break;
    case 1: result.push('Wash Temp: Boost'); break;
    case 2: result.push('Wash Temp: Sanitize'); break;
    default: result.push('Wash Temp: <unknown value ' + washTemp + '>'); break;
  }
  if (data[1] & 0x80)
    result.push('Rinse Aid Enabled'); // press Steam five times in a row to toggle
  if (data[2] & 0x01)
    result.push('Bottle Blast');
  var cycle = ((data[2] & 0x1E) >> 1);
  switch (cycle) {
    case 0: result.push('Cycle: Autosense'); break;
    case 1: result.push('Cycle: Heavy'); break;
    case 2: result.push('Cycle: Normal'); break;
    case 3: result.push('Cycle: Light'); break;
    default: result.push('Cycle: <unknown cycle ' + cycle + '>'); break;
  }
  if (data[2] & 0x20)
    result.push('Leak Detect Enabled');
  if (data[2] & 0x40)
    result.push('Sabbath Mode Enabled'); // hold start and wash temp buttons for five seconds to toggle
  if (data[2] & 0x80)
    result.push('<reserved bit 0x800000 set>');
  return result.join(', ');
}

function reportUserConfiguration(name, data) {
  log(name + ': ' + describeUserConfiguration(data));
}

function describeControlLock(data) {
  if (data == 0x55)
    return 'Locked';
  if (data == 0xAA)
    return 'Unlocked';
  return describe(data);
}

function reportControlLock(name, data) {
  log(name + ': ' + describeControlLock(data));
}

function describeDoorCount(data) {
  if (typeof data != 'number')
    return '<unexpected format: ' + describe(data) + '>';
  return 'door opened and closed ' + data + ' times';
}

function reportDoorCount(name, data) {
  log(name + ': ' + describeDoorCount(data));
}

function describePersonality(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    var result = [];
    switch (data.personality) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
      case 8:
      case 9:
      case 10:
      case 11:
      case 12:
      case 13:
      case 14:
       result.push('UI personality=' + data.personality);
       break;
      case 15:
       result.push('no UI personality (UI board may be hard-wired)');
       break;
      default: throw 'unexpected personality';
    }
    switch (data.source) {
      case 0:
       result.push('source=Bootload Parametric');
       break;
      case 1:
       result.push('source=A/D');
       break;
      default: throw 'unexpected source';
    }
    return result.join(', ');
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportPersonality(name, data) {
  log(name + ': ' + describePersonality(data));
}

function describeCycleState(data) {
  if (typeof data != 'number')
    return '<unexpected format: ' + describe(data) + '>';
  switch (data) {
    case 1: return 'PreWash';
    case 2: return 'Sensing';
    case 3: return 'MainWash';
    case 4: return 'Drying';
    case 5: return 'Sanitizing';
    case 6: return 'Turbidity Calibration';
    case 7: return 'Diverter Calibration';
    case 8: return 'Pause';
    case 9: return 'Rinsing';
    case 10: return 'Cycle Inactive';
    default: return '<unknown: ' + describe(data) + '>';
  }
}

function reportCycleState(name, data) {
  log(name + ': ' + describeCycleState(data));
}

function describeTime(data, includeSeconds) {
  var seconds = data % 60;
  var minutes = includeSeconds ? Math.floor(data / 60) % 60 : Math.round(data / 60) % 60;
  var hours = Math.floor(data / (60 * 60)) % 24;
  var days = Math.floor(data / (60 * 60 * 24));
  var result = '';
  if (days > 0)
    result += days + 'd';
  if (result != '' || hours > 0) {
    if (result != '')
      result += ' ';
    result += hours + 'h';
  }
  if (result != '' || minutes > 0 || !includeSeconds) {
    if (result != '')
      result += ' ';
    result += minutes + 'm';
  }
  if (includeSeconds) {
    if (result != '')
      result += ' ';
    result += seconds + 's';
  }
  return result;
}

function describeTemp(data) { // data is in fahrenheit
  return ((data - 32) * 5 / 9).toFixed(1) + '℃';
}

function pad(value, padding) {
  return padding.substring(0, padding.length - value.length) + value;
}

function describeTimestamp(data) { // seconds since dishwasher epoch
  var date = new Date(data * 1000 + dishwasherEpoch);
  var year = date.getUTCFullYear();
  var month = pad((date.getUTCMonth() + 1).toString(), '00');
  var day = pad((date.getUTCDate()).toString(), '00');
  var hour = pad(date.getUTCHours().toString(), '00');
  var minute = pad(date.getUTCMinutes().toString(), '00');
  return 'on ' + year + '-' + month + '-' + day + ' at ' + hour + ':' + minute;
}

function describeCycleData(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    var result = [];
    if (data.cycleNumber != 0)
      result.push('number=' + data.cycleNumber);
    if ((data.cycleMinimumTemperatureInFahrenheit == 255) &&
        (data.cycleMaximumTemperatureInFahrenheit == 0)) {
      result.push('no temperature data yet');
    } else {
      result.push('temp=' + describeTemp(data.cycleMinimumTemperatureInFahrenheit) + '..' + describeTemp(data.cycleMaximumTemperatureInFahrenheit));
    }
    if (data.cycleFinalCirculationTemperatureInFahrenheit != 0)
      result.push('finalTemp=' + describeTemp(data.cycleFinalCirculationTemperatureInFahrenheit));
    if ((data.cycleMinimumTurbidityInNTU == 65535) &&
        (data.cycleMaximumTurbidityInNTU == 0)) {
      result.push('no turbidity data yet');
    } else {
      result.push('turbidity=' + data.cycleMinimumTurbidityInNTU + '..' + data.cycleMaximumTurbidityInNTU + ' NTU');
    }
    result.push('started ' + describeTimestamp(data.cycleTime * 60));
    switch (data.cycleCompleted) {
      case 0: result.push('incomplete'); break;
      case 1: result.push('completed ' + describeTimestamp(data.cycleTime * 60 + data.cycleDurationInMinutes * 60)); break;
      default: result.push('completed=<unrecognized value ' + describe(data.cycleCompleted) + '>'); break;
    }
    result.push('duration=' + (describeTime(data.cycleDurationInMinutes * 60, false)));
    return result.join(', ');
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportCycleData(name, data) {
  log(name + ': ' + describeCycleData(data));
}

function describeContinuousCycle(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    var result = [];
    result.push('cycle number ' + data.cycleToRun);
    result.push('' + data.cyclesRemaining + ' cycles remaining');
    result.push('' + describeTime(data.cyclesRemaining, false) + ' between cycles');
    return result.join(', ');
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportContinuousCycle(name, data) {
  log(name + ': ' + describeContinuousCycle(data));
}

function describeError(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    if (data.errorState == 0) {
      return 'cleared (was error ' + data.errorId + ')';
    } else {
      return 'error ' + data.errorId + '; state ' + data.errorState;
    }
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportError(name, data) {
  log(name + ': ' + describeError(data));
}

function describeContinuousCycle(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    var result = [];
    result.push('cycle number ' + data.cycleToRun);
    result.push('' + data.cyclesRemaining + ' cycles remaining');
    result.push('' + describeTime(data.cyclesRemaining, false) + ' between cycles');
    return result.join(', ');
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportContinuousCycle(name, data) {
  console.log(name + ': ' + describeContinuousCycle(data));
}

function describeError(data) {
  if (typeof data != 'object')
    return '<unexpected format: ' + describe(data) + '>';
  try {
    if (data.errorState == 0) {
      return 'cleared (was error ' + data.errorId + ')';
    } else {
      return 'error ' + data.errorId + '; state ' + data.errorState;
    }
  } catch (e) {
    return '<' + e + ': ' + describe(data) + '>';
  }
}

function reportError(name, data) {
  console.log(name + ': ' + describeError(data));
}

var fields = {
  // only the first nine of these to which any program subscribes after power cycle will send change updates
  'userConfiguration': reportUserConfiguration,
  'operatingMode': reportOperatingMode,
  'cycleState': reportCycleState,
  'cycleStatus': reportCycleStatus,
  'doorCount': reportDoorCount,

  // status ring buffer
  'cycleData0': reportCycleData,
  'cycleData1': reportCycleData,
  'cycleData2': reportCycleData,
  'cycleData3': reportCycleData,
  'cycleData4': reportCycleData,

  'reminders': reportReminders, // this is unreliable at best, and can be polled at worst

  'cycleCounts': reportCycleCounts, // not clear how useful this really is

  'error': reportError, // ???
  'rates': reportRates, // ???
  'continuousCycle': reportContinuousCycle, // ???

  'analogData': reportAnalogData, // sends lots of bogus data continuously
  'dryDrainCounters': reportDryDrainCounters, // sends updates continuously despite no change

  'personality': reportPersonality, // never changes
  'disabledFeatures': reportDisabledFeatures, // never changes?

  'controlLock': reportControlLock, // ???

  // 'modelNumber': report,
  // 'serialNumber': report,
  // 'remoteEnable': report,
  // 'userInterfaceLock': report,
  // 'clockTime': report,
  // 'clockFormat': report,
  // 'temperatureDisplayUnits': report,
  // 'applianceType': report,
  // 'sabbathMode': report,
  // 'soundLevel': report,
  
  // the following are documented but fail on the GDF570SGFWW or with this SDK (not clear which)
  // 'turbidityCalibration': report,
  // 'diverterCalibration': report,
  // 'tubLight': report,
};

var numericFields = [
  'operatingMode', 'disabledFeatures', 'reminders', 'controlLock', 'cycleState'
];

function getRegistration(field, dishwasher) {
  pendingCount += 1;
  var reportCount = 0;
  return function () {
    var timeout = setTimeout(function () {
      // log('timed out waiting for initial response for ' + field);
      pendingCount -= 1;
      reportCount += 1;
      if (pendingCount == 0)
        rl.prompt();
    }, timeoutTime);
    timeout.unref();
    dishwasher[field].subscribe(function (value) {
      clearTimeout(timeout);
      fields[field](field, value);
      if (reportCount == 0)
        pendingCount -= 1;
      reportCount += 1;
      if (pendingCount == 0)
        rl.prompt();
    });
  };
}

function getReader(field, dishwasher) {
  pendingCount += 1;
  return function () {
    var timeout = setTimeout(function () {
      log('timed out waiting for response for ' + field);
      pendingCount -= 1;
      if (pendingCount == 0)
        rl.prompt();
    }, timeoutTime);
    timeout.unref();
    dishwasher[field].read(function (value) {
      clearTimeout(timeout);
      fields[field](field, value);
      pendingCount -= 1;
      if (pendingCount == 0)
        rl.prompt();
    });
  };
}

var dishwasher;
greenBean.connect("dishwasher", function(dw) {
  log('dishwasher connection detected - version=' + dw.version.join('.') + '; address=' + dw.address.toString(16));
  if (dishwasher == null) {
    dw.operatingMode.read(function (value) {
      if (value == 11) {
        // this is a bogus object; see:
        // https://github.com/GEMakers/gea-plugin-dishwasher/issues/6
        // https://github.com/GEMakers/gea-plugin-dishwasher/issues/4
        return;
      }
      dishwasher = dw;
      log('selected dishwasher at address ' + dw.address.toString(16));

      // dishwasher.send(0x01, [], function (data) {
      //   log("version: " + data);
      // });
      
      index = 0;
      for (var field in fields) {
        setTimeout(getReader(field, dw), index * delayTime);
        setTimeout(getRegistration(field, dw), index * delayTime + delayTime / 2);
        index += 1;
      }
      setTimeout(function () {
        pendingCount -= 1;
        if (pendingCount == 0)
          rl.prompt();
      }, index * delayTime);
    });
  }
});

rl.on('line', (line) => {
  var words = line.trim().split(/ +/);
  switch (words[0]) {
    case '':
      break;
    case 'help':
      log('commands:');
      log('  <field>: read the field');
      log('  raw <field>: read the field and display raw data');
      log('  all: read all fields');
      log('  available fields are:');
      for (var field in fields) {
        if (field in dishwasher)
          log('    ' + field);
      }
      for (var index = 0; index < numericFields.length; index += 1) {
        var field = numericFields[index];
        log('  set ' + field + ' <n>: set this field to <n>');
      }
      log('  set personality <personality> <source>: set personality to <personality> with <source>');
      log('');
      break;
    case 'sensors':
      dishwasher.analogData.read(reportAnalogData);
      break;
    case 'all':
      if (words.length == 1) {
        index = 0;
        for (var field in fields) {
          setTimeout(getReader(field, dishwasher), index * delayTime);
          index += 1;
        }
      } else {
        log('Command not recognised: "' + line + '" (' + words.length + ' words)\n');
      }
      break;
    case 'set':
      if (words[1] == 'personality') {
        var field = 'personality';
        if (words.length == 4) {
          try {
            var personality = parseInt(words[2]);
            var source = parseInt(words[3]);
            var value = {
              personality: personality,
              source: source
            };
            log('Setting "' + field + '" to ' + describe(value));
            dishwasher[field].write(value);
            setTimeout(getReader(field, dishwasher), delayTime);
          } catch (e) {
            log(e);
          }
        } else {
          log('syntax: set personality <personality> <source>');
        }
        break;
      } if (words.length == 3) {
        var field = words[1];
        if (numericFields.indexOf(field) >= 0) {
          try {
            var value = parseInt(words[2]);
            log('Setting "' + field + '" to ' + value);
            dishwasher[field].write(value);
          } catch (e) {
            log(e);
          }
        } else {
          log('Field not recognised: "' + field + '"\n');
        }
      } else {
        log('Command not recognised: "' + line + '" (' + words.length + ' words)\n');
      }
      break;
    case 'raw':
      if (words.length == 2) {
        var field = words[1];
        if (field in fields) {
          dishwasher[field].read(function (data) { report(field, data); });
        } else {
          log('Field not recognised: "' + field + '"\n');
        }
      } else {
        log('Command not recognised: "' + line + '" (' + words.length + ' words)\n');
      }
      break;
    default:
      if (words.length == 1) {
        var field = words[0];
        if (field in fields) {
          dishwasher[field].read(getReader(field, dishwasher));
        } else {
          log('Field not recognised: "' + field + '"\n');
        }
      } else {
        log('Command not recognised: "' + line + '" (' + words.length + ' words)\n');
      }
      break;
  }
  // log('pendingCount = ' + pendingCount);
  if (pendingCount == 0)
    rl.prompt();
}).on('close', () => {
  log('Terminating dishwasher console.');
  process.exit(0);
});

if (keepAliveTime > 0) {
  setInterval(function () {
    if (dishwasher != null)
      dishwasher.doorCount.read(function (value) { });
  }, keepAliveTime);
}
