#!/bin/bash 

## init ##
STOCK_IMAGE="ubuntu"
SIZE=1000000

track_stats() {
	
	DATE=$(date +%Y-%m-%d_%H_%M_%S)
	STATS_FILE=$1_stats_$DATE.txt
	touch error.txt
	while true; do
		docker stats --no-stream=true $1 >> $STATS_FILE 2>> error.txt
		ERROR=$(wc -l < error.txt)
		if [ $ERROR -ne 0 ]; then
			exit 0
		fi
		sleep 0.5
	done
}

# Retrieve container IP given ID
get_container_ip() {
	docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$@"
}

for IMAGE in rsyslog; do
	
	echo "Running $IMAGE container and initializating stat tracking"
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
	echo "$IMAGE : expected ~3000000"
	BASE="0"
	if [ "$IMAGE" == "rsyslog" ]; then
		while true; do
				NEW=$(docker exec $CID wc -l /var/log/syslog | awk {'print $1 '})
				echo "NEW=$NEW BASE=$BASE"
				if [ "$NEW" == "$BASE" ]; then
					echo "RETRIEVED $NEW"
					break
				fi
				BASE=$NEW
		done
	elif [ "$IMAGE" == "logstash" ]; then
		docker exec $CID wc -l  < /var/log/logstash_ingest.log
	fi

	read -p "Press any key to continue.."
	echo "Removing $IMAGE container."
	docker rm -f $IMAGE
	docker rm -f $(docker ps -aq)

done
