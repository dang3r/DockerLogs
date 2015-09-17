#!/bin/bash

## init ##
STOCK_IMAGE="ubuntu"
SIZE=1000000

# 1 : container name
track_stats() {
	NAME=$1
	DATE=$(date +%Y-%m-%d_%H_%M_%S)
	STATS_FILE=$1_stats_$DATE.txt
	
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

# 1 : container name
get_container_ip() {
	docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$@"
}

get_container_names() {
	docker inspect --format='{{.Name}}' $(docker ps -aq) 2> /dev/null
}

for IMAGE in rsyslog; do
	
	echo "Running $IMAGE container and initializing stat tracking"
	CID=$(docker run -d --name $IMAGE --privileged $IMAGE)
	CIP=$(get_container_ip $CID)
	track_stats $IMAGE &
	sleep 5
	
	echo "Initializing tenant containers."
	for i in {0..2}; do
		NAME="test_$IMAGE_$i"
		docker run \
			--detach=true \
			--name $NAME \
			--env CLIENT=$i \
			--privileged \
			--log-driver=syslog \
			--log-opt syslog-address=tcp://$CIP:1338 \
			$STOCK_IMAGE \
			bash -c 'for i in {0..1000000}; do echo "Client$CLIENT_$i"; done'
	done

	echo "Waiting for tenant containers to die."
	while true; do
			if [ $(docker ps -q | wc -l) -eq 1 ]; then
					break
			fi
			sleep 5
	done

	sleep 10
	echo "Expecting 3000003 messages for $IMAGE"
	BASE="0"

	# Retrieve, verify logs
	if [ "$IMAGE" == "rsyslog" ]; then
		while true; do
				NEW=$(docker exec $CID wc -l /var/log/docker.log | awk {'print $1 '})
				if [ "$NEW" == "$BASE" ]; then
					echo "Retrieved $NEW messages for $IMAGE"
					break
				fi
				BASE=$NEW
		done
	elif [ "$IMAGE" == "logstash" ]; then
		docker exec $CID wc -l  < /var/log/logstash_ingest.log
	fi

	echo "Removing $IMAGE containers."
	docker rm -f $IMAGE
	docker rm -f $(docker ps -aq)

done
