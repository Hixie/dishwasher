// This has only been tested with a GE GDF570SGFWW dishwasher

require('events').EventEmitter.prototype._maxListeners = 0;

const greenBean = require("green-bean");

var delayTime = 1000; // milliseconds between messages to dishwasher
var fields = [ 'userConfiguration', 'operatingMode', 'cycleState', 'cycleStatus', 'error' ];
var pendingDishwasherMessages = [];
var lastMessage = 0;

function flushPendingDishwasherMessages() {
  var callback = pendingDishwasherMessages.shift();
  callback();
  if (pendingDishwasherMessages.length > 0)
    setTimeout(flushPendingDishwasherMessages, delayTime);
}

function sendDishwasherMessage(callback) {
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
      console.log(field, value);
    });
  });
}

//
//   1 Delay start | 0=0h          4-15=?
//   2 Delay start | 1=2h
//   4 Delay start | 2=4h
//   8 Delay start | 3=8h
//  16 Zone        |
//  32 Zone        |
//  64 Demo mode   |
// 128 Mute        |
//
//   1 Steam       |
//   2 UI Locked   |
//   4 Dry options | 0=Idle        8,12=?
//   8 Dry options | 4=Heated
//  16 Wash temp   | 0=Normal
//  32 Wash temp   | 16=Boost      48,64,80,96,112=?
//  64 Wash temp   | 32=Sanitize
// 128 Rinse Aid   | ALWAYS ON
//
//   1 Bottle Blast|
//   2 Cycle       | 0=autosense
//   4 Cycle       | 2=heavy       8,10,12,14,16,18
//   8 Cycle       | 4=normal      20,22,24,26,28,30=?
//  16 Cycle       | 6=light
//  32 Leak Detect | ALWAYS ON
//  64 Sabbath     |
// 128 Reserved    |

function doTest() {
  sendDishwasherMessage(function () {
    console.log('writing to userConfiguration...');
    dishwasher.userConfiguration.write([0, 1+4+32+128, 0+32]);
  });
}

var dishwasher;
console.log('connecting to green bean');
greenBean.connect("dishwasher", function(dw) {
  if (dishwasher == null) {
    dw.operatingMode.read(function (value) {
      if (value == 11)
        return;
      dishwasher = dw;
      console.log('connected...');
      for (var index = 0; index < fields.length; index += 1)
        subscribe(dishwasher, fields[index]);
      setTimeout(doTest, 2000);
    });
  }
});
