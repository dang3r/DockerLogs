#!/bin/bash
#

# Ensure no docker daemon is present
for fs in $1; do
	echo "$fs : Beginning test run"
	docker daemon --storage-driver=$fs > /dev/null 2>&1 & 
	DPID=$?
	echo "$fs : Launch docker daemon $DPID"
	
	cd docker
	./build.sh
	cd ..

	for proto in tcp udp; do
		echo "$fs $proto : Launching test suite"		
		./test.sh $fs $proto
		echo "$fs $proto : Finished test"
	done
	
	echo "Finished $fs tests"
	#sudo kill $DPID
	#sleep 5
done
