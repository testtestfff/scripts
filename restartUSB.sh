#!/bin/bash

if [ $# -eq 0 ]
then
   echo "parametre manquant"
   exit 1
fi

filepath=$(find /sys/bus/usb/devices/usb*/ -maxdepth 12 -name 'serial' -type f -print0 | xargs -0 -I % sh -c 'echo -n %,; cat %' | tr '\\n' ',' | awk -F ',' -v var="$(ls -al /dev/disk/by-id/ | grep $(mount | grep $(df $1 | tail -1 | awk '{ print $6 }') | awk -F ' on' '{print $1}' | awk -F '/' '{print $NF}')))" '{for (i=1; i<=NF; i++) if ( match(var, $i) && length($i) > 0) { printf $(i-1) "\n" } }' | awk -F '/serial' '{print $1}')/authorized


#find /sys/bus/usb/devices/usb*/ -maxdepth 12 -name 'serial' -type f -print0 | xargs -0 -I % sh -c 'echo -n %,; cat %; echo -n %,; echo -e $(echo test)' | tr '\n' ','
#idascii=$(echo -e $(echo "$id" | awk -F '' '{for (i=1; i<=NF; i++) { printf (i%2 == 1) ? "\\x"$i:$i;} printf "\n"}'))


echo "filepath : $filepath"
exit
echo 0 | sudo tee -a $filepath &> /dev/null

sleep 3

echo 1 | sudo tee -a $filepath &> /dev/null




