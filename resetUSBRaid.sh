#!/bin/bash

if [ $# -eq 0 ]
then
   echo "passer un fichier en parametre"
   exit 1
fi

echo "fichier : $1"
standard=false

for elem in $(find /sys/bus/usb/devices/usb*/ -maxdepth 4 -name "serial" -type f -print0 | xargs -0 -I % sh -c 'echo -n %--; cat %')
do
   echo "elem : $elem"
   id=$(echo "$elem" | awk -F '--' '{print $NF}')
   folder=$(echo "$elem" | awk -F 'serial' '{print $(NF-1)}')
   if ls -al "/dev/disk/by-id/" | grep $(mount | grep $(df $1 | tail -1 | awk '{ print $6 }') | awk -F ' on' '{print $1}' | awk -F '/' '{print $NF}') | grep "$id" > /dev/null
   then
      echo "OK : $folder"
      standard=true
   fi
done

if ! $standard
then
   echo "not standard"
   # detecte raid
   partition=$(mount | grep $(df $1 | tail -1 | awk '{ print $6 }') | awk -F ' on' '{print $1}')
   echo "partition : $partition"
   raidpart=$(sudo mdadm --detail $partition | grep "/dev/sd" | awk -F '/dev/' '{print $NF}')
   echo "raidpart : $raidpart"
   for elem in $(find /sys/bus/usb/devices/usb*/ -maxdepth 4 -name "serial" -type f -print0 | xargs -0 -I % sh -c 'echo -n %--; cat %')
   do
      echo "elem : $elem"
      id=$(echo "$elem" | awk -F '--' '{print $NF}')
      folder=$(echo "$elem" | awk -F 'serial' '{print $(NF-1)}')
      if ls -al "/dev/disk/by-id/" | grep "$raidpart" | grep "$id" > /dev/null
      then
         echo "OK : $folder"
         standard=true
      fi
   done
else
   echo "standard"
fi

exit
