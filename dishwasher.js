// This has only been tested with a GE GDF570SGFWW dishwasher

require('events').EventEmitter.prototype._maxListeners = 0;

const delayTime = 1500;
const keepAliveTime = -2000; // negative means disabled

const greenBean = require("green-bean");
const readline = require('readline');
const rl = readline.createInterface(process.stdin, process.stdout);
rl.setPrompt('dishwasher> ');

var pendingCount = 1;

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
    console.log('');
  console.log(name + ': ' + describe(data));
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
      case 1: result.push('active'); break;
      default: throw 'unexpected cycleRunning';
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
  console.log(name + ': ' + describeCycleStatus(data));
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
  console.log(name + ': ' + describeAnalogData(data));
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
    default: return '<unknown: ' + describe(data) + '>';
  }
}

function reportOperatingMode(name, data) {
  console.log(name + ': ' + describeOperatingMode(data));
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
    return '<no disabled features>';
  return result.join(', ');
}

function reportDisabledFeatures(name, data) {
  console.log(name + ': ' + describeDisabledFeatures(data));
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
    return '<no reminders>';
  return result.join(', ');
}

function reportReminders(name, data) {
  console.log(name + ': ' + describeReminders(data));
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
  console.log(name + ': ' + describeUserConfiguration(data));
}

function describeControlLock(data) {
  if (data == 0x55)
    return 'Locked';
  if (data == 0xAA)
    return 'Unlocked';
  return describe(data);
}

function reportControlLock(name, data) {
  console.log(name + ': ' + describeControlLock(data));
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
  console.log(name + ': ' + describeCycleState(data));
}

var fields = {
  'cycleStatus': reportCycleStatus,
  'operatingMode': reportOperatingMode,
  'disabledFeatures': reportDisabledFeatures,
  'reminders': reportReminders,
  'rates': report,
  // ' turbidityCalibration': report,
  'doorCount': report,
  'userConfiguration': reportUserConfiguration,
  'error': report,
  'cycleCounts': report,
  'continuousCycle': report,
  'controlLock': reportControlLock,
  'personality': report,
  // 'diverterCalibration': report,
  'cycleState': reportCycleState,
  'analogData': reportAnalogData,
  'cycleData0': report,
  'cycleData1': report,
  'cycleData2': report,
  'cycleData3': report,
  'cycleData4': report,
  'dryDrainCounters': report,
  // 'tubLight': report,
};

var numericFields = [
  'operatingMode', 'disabledFeatures', 'reminders', 'controlLock', 'cycleState'
];

var dishwasher;

function getRegistration(field) {
  pendingCount += 1;
  return function () {
    // console.log('registering listener for ' + field);
    dishwasher[field].subscribe(function (data) { fields[field](field, data); });
    pendingCount -= 1;
    if (pendingCount == 0)
      rl.prompt();
  };
}

function getReader(field) {
  pendingCount += 1;
  return function () {
    var timeout = setTimeout(function () {
      console.log('timed out waiting for response for ' + field);
      pendingCount -= 1;
      if (pendingCount == 0)
        rl.prompt();
    }, delayTime);
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

var dishwasherCount = 0;
greenBean.connect("dishwasher", function(dw) {
  dishwasherCount += 1;
  if (dishwasherCount == 0)
    return;
  if (dishwasher != null) {
    if (dw != dishwasher) {
      console.log('dishwasher callback invoked multiple times; ignoring all but first');
    } else {
      console.log('redundant dishwasher registration');
    }
    return;
  }
  dishwasher = dw;
  index = 0;
  for (var field in fields) {
    setTimeout(getRegistration(field), index * delayTime);
    index += 1;
  }
  pendingCount -= 1;
});

rl.on('line', (line) => {
  var words = line.trim().split(/ +/);
  switch (words[0]) {
    case '':
      break;
    case 'help':
      console.log('commands:');
      console.log('  <field>: read the field');
      console.log('  raw <field>: read the field and display raw data');
      console.log('  all: read all fields');
      console.log('  available fields are:');
      for (var field in fields) {
        if (field in dishwasher)
          console.log('    ' + field);
      }
      for (var index = 0; index < numericFields.length; index += 1) {
        var field = numericFields[index];
        console.log('  set ' + field + ' <n>: set this field to <n>');
      }
      console.log('  set personality <personality> <source>: set personality to <personality> with <source>');
      console.log('');
      break;
    case 'sensors':
      dishwasher.analogData.read(reportAnalogData);
      break;
    case 'all':
      if (words.length == 1) {
        index = 0;
        for (var field in fields) {
          setTimeout(getReader(field), index * delayTime);
          index += 1;
        }
      } else {
        console.log('Command not recognised: "' + line + '" (' + words.length + ' words)\n');
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
            console.log('Setting "' + field + '" to ' + describe(value));
            dishwasher[field].write(value);
            setTimeout(getReader(field), delayTime);
          } catch (e) {
            console.log(e);
          }
        } else {
          console.log('syntax: set personality <personality> <source>');
        }
        break;
      } if (words.length == 3) {
        var field = words[1];
        if (numericFields.indexOf(field) >= 0) {
          try {
            var value = parseInt(words[2]);
            console.log('Setting "' + field + '" to ' + value);
            dishwasher[field].write(value);
          } catch (e) {
            console.log(e);
          }
        } else {
          console.log('Field not recognised: "' + field + '"\n');
        }
      } else {
        console.log('Command not recognised: "' + line + '" (' + words.length + ' words)\n');
      }
      break;
    case 'raw':
      if (words.length == 2) {
        var field = words[1];
        if (field in fields) {
          dishwasher[field].read(function (data) { report(field, data); });
        } else {
          console.log('Field not recognised: "' + field + '"\n');
        }
      } else {
        console.log('Command not recognised: "' + line + '" (' + words.length + ' words)\n');
      }
      break;
    default:
      if (words.length == 1) {
        var field = words[0];
        if (field in fields) {
          dishwasher[field].read(function (data) { fields[field](field, data); });
        } else {
          console.log('Field not recognised: "' + field + '"\n');
        }
      } else {
        console.log('Command not recognised: "' + line + '" (' + words.length + ' words)\n');
      }
      break;
  }
  if (pendingCount == 0)
    rl.prompt();
}).on('close', () => {
  console.log('Terminating dishwasher console.');
  process.exit(0);
});

if (keepAliveTime > 0) {
  setInterval(function () {
    if (dishwasher != null)
      dishwasher.doorCount.read(function (value) { });
  }, keepAliveTime);
}
