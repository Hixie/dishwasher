echo -n "Running as: "; id -u -n
(cd /home/ianh/dishwasher/model/; dart --checked lib/main.dart --ansi --hub-config remy.cfg ../../logs-proxy.js/)
