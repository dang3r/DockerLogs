#!/bin/bash

## init ##
dpkg -i /tmp/splunklight-6.2.6-274160-linux-2.6-amd64.deb 
/opt/splunk/bin/splunk start --accept-license

## add ports ##
/usr/bin/expect << EOF
spawn /opt/splunk/bin/splunk add udp 1337 -sourcetype syslog
expect "Splunk username: "
send "admin\r"
expect "Password: "
send "changeme\r"
expect eof
EOF

/opt/splunk/bin/splunk add tcp 1338 -sourcetype syslog
sleep infinity
