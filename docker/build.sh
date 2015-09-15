#!/bin/bash
#
# Build the docker images for rsyslog, logstash, splunk

for TYPE in rsyslog; do
docker build \
  -t $TYPE \
  --file="Dockerfile.$TYPE" \
	--rm=true \
	.
done
