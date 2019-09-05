echo -n "Running as: "; id -u -n
(cd /home/ianh/dishwasher/model/; /home/ianh/dev/dart-sdk/sdk/sdk/bin/dart --checked lib/main.dart --ansi --hub-config remy.cfg ../../logs-proxy.js/)
