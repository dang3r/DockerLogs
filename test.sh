#!/bin/bash
#
# Given a running docker daemon, run the test suite
# 1 : FS - AUFS, overlay
# 2 : proto - udp(1337), tcp(1338)

## init ##
STOCK_IMAGE="ubuntu"
STATS="logs/stats.txt"
rsyslog_log="/var/log/docker.log"
logstash_log="/var/log/docker_ingest.log"

DATE=$(date +%Y-%m-%d_%H_%M_%S)
FS=$1
PROTO=$2
if [ $PROTO == "udp" ]; then
		PORT=1337
else
		PORT=1338
fi

# Log the runtime metrics of a container to file
# 1 : container name
track_stats() {
	mkdir -p logs
	NAME=$1
	STATS_FILE="logs/$1_stats_$DATE.txt"
	echo $FS PROTO >> $STATS_FILE	
	while true; do
		docker stats --no-stream=true $NAME | \
				awk 'NR==2'  1>> $STATS_FILE 2>> /dev/null
		( get_container_names	) | grep -q $NAME
		ERROR=$?
		if [ $ERROR -ne 0 ]; then
			exit 0
		fi
		sleep 1
	done
}

# Return the IP of a container
# 1 : container name
get_container_ip() {
	docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$@"
}

# Return the names of all present containers
get_container_names() {
	docker inspect --format='{{.Name}}' $(docker ps -aq) 2> /dev/null
}


docker rm -f `docker ps -aq`
echo "Removing host splunk directory"
sudo rm -r /tmp/splunk/
mkdir /tmp/splunk/

for IMAGE in splunk rsyslog logstash; do
	echo "$IMAGE : Run logging container."
	CID=$(docker run -d --name $IMAGE -v /tmp/splunk/:/opt/splunk/:rw --privileged $IMAGE)
	CIP=$(get_container_ip $CID)
	sleep 15

	echo "$IMAGE : Log runtime metrics"
	track_stats $IMAGE &
	START=$(date +"%s")	

	echo "$IMAGE : Run tenant containers."
	for i in {0..2}; do
		NAME="test_$IMAGE_$i"
		docker run \
			--detach=true \
			--name $NAME \
			--env CLIENT=$i \
			--privileged \
			--log-driver=syslog \
			--log-opt syslog-address=$PROTO://$CIP:$PORT \
			$STOCK_IMAGE \
			bash -c 'for i in {0..1000000}; do echo "$HOSTNAME_message_$i"; done'
		sleep 5
	done

	echo "$IMAGE : Wait for tenant container termination."
	while true; do
			if [ $(docker ps -q | wc -l) -eq 1 ]; then
					break
			fi
			sleep 1
	done
	
	echo "Expecting 3000003 messages for $IMAGE"
	BASE="0"

	# Retrieve, verify logs
	CMD=0
	if [ "$IMAGE" == "rsyslog" ]; then
		CMD="docker exec $CID wc -l /var/log/docker.log | awk {'print \$1 '}"
	elif [ "$IMAGE" == "logstash" ]; then
		CMD="docker exec $CID wc -l /var/log/docker_ingest.log | awk {'print \$1 '}"
	elif [ "$IMAGE" == "splunk" ]; then
		CMD="docker exec $CID /opt/splunk/bin/splunk search 'source=\"$PROTO:$PORT\" | stats count as Total' -auth admin:changeme | tail -n 1"
	fi

	# Repeatedly check the number of log messages until it is static
	while true; do
				NEW=$(eval $CMD)
				if [ "$NEW" == "$BASE" ]; then
					END=$( date +"%s")
					echo "$IMAGE : Retrieved $NEW messages for $IMAGE"
					echo $FS $PROTO $IMAGE $NEW $(($END-$START)) >> $STATS
					break
				fi
				BASE=$NEW
				sleep 3
	done

	echo "$IMAGE : Removing all containers."
	docker rm -f $IMAGE > /dev/null
	docker rm -f $(docker ps -aq) > /dev/null

done
