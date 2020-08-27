#!/bin/bash
echo -n "Running as: "; id -u -n
echo "(This needs to run as root to work.)"
while (true); do (cd /home/ianh/dev/dishwasher/proxy; node --abort-on-uncaught-exception dishwasher-to-websocket-proxy.js | tee -a "../../../logs/dishwasher-proxy/`date +%Y-%m-%dT%H:%M:%S`.log"); done
