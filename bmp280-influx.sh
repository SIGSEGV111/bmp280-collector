#!/bin/bash

set -e
set -u
set -o pipefail

exec 0</dev/null
P="$(dirname "$(readlink -f "$0")")"

set -x
source "/etc/location.conf"
set +x

echo "Country: $COUNTRY"
echo "City: $CITY"
echo "Building: $BUILDING"
echo "Floor: $FLOOR"
echo "Wing: $WING"
echo "Room: $ROOM"

cd "/sys/bus/iio/devices/iio:device0"

echo 16 > in_pressure_oversampling_ratio
echo 16 > in_temp_oversampling_ratio

mkdir -p "/var/lib/bmp280"
exec 3>>"/var/lib/bmp280/csv"
flock --exclusive --nonblock 3

exec >/var/log/bmp280.log 2>&1
set +e

while true; do
	read p < in_pressure_input
	read t < in_temp_input
	ts="$(echo "$(date '+%s.%N')*1000000000.0" | bc -l | grep -o "^[^\.]\+")"
	t="$(echo "$t/1000.0" | bc -l)"
	echo "$ts;$t;$p" 1>&3
	data="environment,country=$COUNTRY,city=$CITY,building=$BUILDING,floor=$FLOOR,wing=$WING,room=$ROOM,location=$BUILDING-$WING$FLOOR.$ROOM pressure=$p,temperature_bmp280=$t $ts"
	curl --silent -XPOST "http://$SERVER/write?db=data" --data-binary "$data"
	sleep 5
done &
