// This has only been tested with a GE GDF570SGFWW dishwasher

// This is an adapter from the Green Bean SDK to the dishwasher model
// server in the model/ directory.

function assert(condition) {
  if (!condition)
    throw 'assertion failed';
}

var reconnectTimeout = 2000; // milliseconds between connections to websocket server
var delayTime = 1000; // milliseconds between messages to dishwasher


// WEBSOCKET LOGIC
// updateModel() is the public API of this section

var WebSocketClient = require('websocket').client;
var dishwasherModel;
var lastDataForEachField = {};
function connect() {
  function reconnect() {
    var oldDishwasherModel = dishwasherModel;
    dishwasherModel = null;
    if (oldDishwasherModel != null && oldDishwasherModel.connected)
      oldDishwasherModel.close();
    setTimeout(connect, reconnectTimeout);
  }
  var webSocketAPI = new WebSocketClient();
  webSocketAPI.on('connectFailed', function (error) {
    console.log('Error connecting to dishwasher model server: ' + error.toString());
    reconnect();
  });
  webSocketAPI.on('connect', function (newConnection) {
    assert(dishwasherModel == null);
    dishwasherModel = newConnection;
    dishwasherModel.on('error', function (error) {
      console.log('Error with connection to dishwasher model server: ' + error.toString());
      reconnect();
    });
    dishwasherModel.on('close', function() {
      console.log('Connection to dishwasher model server closed.');
      reconnect();
    });
    dishwasherModel.on('message', function (message) {
      if (message.type === 'utf8')
        console.log("Received from dishwasher model: '" + message.utf8Data + "'");
    });
    for (var field in lastDataForEachField)
      dishwasherModel.sendUTF(lastDataForEachField[field]);
  });
  webSocketAPI.connect('ws://localhost:2000/', 'dishwasher-model');
}
function updateModel(field, data) {
  var time = Date.now();
  var message = '' + time + '\0' + field + '\0' + JSON.stringify(data);
  console.log('sending to model: ' + message);
  lastDataForEachField[field] = message;
  if (dishwasherModel != null && dishwasherModel.connected)
    dishwasherModel.sendUTF(message);
}
connect();


// GREEN BEAN LOGIC

require('events').EventEmitter.prototype._maxListeners = 0;

const greenBean = require("green-bean");

var fields = [
  // only the first nine of these to which any program subscribes after power cycle will send change updates
  'userConfiguration',
  'cycleData0',
  'cycleData1',
  'cycleData2',
  'cycleData3',
  'cycleData4',
  'operatingMode',
  'cycleState',
  'cycleStatus',

  'doorCount',

  'reminders',
  'cycleCounts',
  'error',
  'rates',
  'continuousCycle',
  'analogData',
  'dryDrainCounters',
  'personality',
  'disabledFeatures',
  'controlLock',

  // the following are documented but fail on the GDF570SGFWW or with this SDK (not clear which)
  // 'turbidityCalibration',
  // 'diverterCalibration',
  // 'tubLight',
];

var pendingDishwasherMessages = [];
var lastMessage = 0;

function flushPendingDishwasherMessages() {
  var callback = pendingDishwasherMessages.shift();
  callback();
  if (pendingDishwasherMessages.length > 0)
    setTimeout(flushPendingDishwasherMessages, delayTime);
}

function sendDishwasherMessage(callback) {
  // possible cases:
  //  - last message was long ago, no pending messages
  //     - send it right away
  //  - last message was recent, no pending messages
  //     - queue it and start the timer
  //  - there's at least one pending message already
  //     - queue it, timer already going
  if (pendingDishwasherMessages.length > 0) {
    pendingDishwasherMessages.push(callback);
    return;
  }
  var now = Date.now();
  var timeSinceLastMessage = now - lastMessage;
  if (timeSinceLastMessage > delayTime) {
    callback();
    lastMessage = now;
    return;
  }
  pendingDishwasherMessages.push(callback);
  setTimeout(flushPendingDishwasherMessages, delayTime - timeSinceLastMessage);
}

function subscribe(dishwasher, field) {
  sendDishwasherMessage(function () {
    dishwasher[field].subscribe(function (value) {
      updateModel(field, value);
    });
  });
}

function read(dishwasher, field) {
  sendDishwasherMessage(function () {
    dishwasher[field].read(function (value) {
      updateModel(field, value);
    });
  });
}

function readAll() {
  if (dishwasher == null)
    return;
  if (pendingDishwasherMessages.length > 0)
    return;
  for (var index = 0; index < fields.length; index += 1) {
    var field = fields[index];
    read(dishwasher, field);
  }
}

var dishwasher;
greenBean.connect("dishwasher", function(dw) {
  if (dishwasher == null) {
    dw.operatingMode.read(function (value) {
      if (value == 11) {
        // this is a bogus object; see:
        // https://github.com/GEMakers/gea-plugin-dishwasher/issues/6
        // https://github.com/GEMakers/gea-plugin-dishwasher/issues/4
        return;
      }
      dishwasher = dw;
      for (var index = 0; index < fields.length; index += 1) {
        var field = fields[index];
        subscribe(dishwasher, field);
        read(dishwasher, field);
      }
    });
  }
});

setInterval(readAll, 60 * 1000);
