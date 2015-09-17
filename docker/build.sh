#!/bin/bash
#
# Build the docker images for rsyslog, logstash, splunk

## init ##
IMAGES=$@
if [ $# -eq 0 ]; then
	echo "No arguments provided. Building all"
	IMAGES='rsyslog logstash splunk'
else
	IMAGES=$@
fi

## build ##
for IMAGE in $IMAGES; do
  echo "Building image for $IMAGE"
	docker build \
  -t $IMAGE \
	-q \
  --force-rm=true \
	--file="Dockerfile.$IMAGE" \
	.
done
