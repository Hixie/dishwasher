echo -n "Running as: "; id -u -n
(cd /home/ianh/dev/dishwasher/model/; /home/ianh/dev/dart-sdk/bin/dart --enable-asserts lib/main.dart --ansi --hub-config remy.cfg ../../../logs/dishwasher-proxy/)
