echo -n "Running as: "; id -u -n
(cd /home/ianh/dev/dishwasher/model/; /home/ianh/dev/dart-sdk/sdk/sdk/bin/dart --checked lib/main.dart --ansi --hub-config remy.cfg ../../../dishwasher-proxy/)
