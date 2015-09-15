#!/bin/bash -ex

# Retrieve container IP given ID
get_container_ip() {
	docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$@"
}

for IMAGE in rsyslog logstash; do
	CID=$(docker run -d --name $IMAGE --privileged $IMAGE)
	CIP=$(get_container_ip $CID)
	sleep 5
	for i in {0..2}; do
		NAME="test_$i"
		SIZE=1000000
		docker run \
			--name $NAME \
			--privileged \
			--log-driver=syslog \
			--log-opt syslog-address=tcp://$CIP:1338 \
			ubuntu \
			bash -c 'for i in {0..1000000}; do echo "3BWTR_Message$i"; done'
		docker rm -f $NAME
	done
	echo "$IMAGE : expected ~3000000"
	if [ "$IMAGE" == "rsyslog" ]; then
		docker exec -ti $CID wc -l /var/log/syslog
	elif [ "$IMAGE" == "logstash" ]; then
		docker exec -ti $CID wc -l /var/log/logstash_ingest.log
	fi
	
	read -p "Press any key to continue.."
done
