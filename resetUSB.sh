#!/bin/bash

if [ $# -eq 0 ]
then
   echo "passer un fichier en parametre"
   exit 1
fi

echo "fichier : $1"

#OK : /sys/bus/usb/devices/usb2/2-1/2-1.4/2-1.4.4/2-1.4.4.4/2-1.4.4.4.1/2-1.4.4.4.1.2/
#root@alex-G73Sw:/sys/bus/usb/drivers/usb# echo '2-1.4.4.4.1.2' | tee unbind
#2-1.4.4.4.1.2
#root@alex-G73Sw:/sys/bus/usb/drivers/usb# echo '2-1.4.4.4.1.2' | tee bind
#2-1.4.4.4.1.2

fullid=$(ls -al "/dev/disk/by-id/" | grep $(mount | grep $(df $1 | tail -1 | awk '{ print $6 }') | awk -F ' on' '{print $1}' | awk -F '/' '{print $NF}'))

echo "fullid : $fullid"

for elem in $(find /sys/bus/usb/devices/usb*/ -maxdepth 12 -name "serial" -type f -print0 | xargs -0 -I % sh -c 'echo -n %--; cat %')
do
   echo "elem : $elem"
   id=$(echo "$elem" | awk -F '--' '{print $NF}')
   echo "id : $id"
   idascii=$(echo -e $(echo "$id" | awk -F '' '{for (i=1; i<=NF; i++) { printf (i%2 == 1) ? "\\x"$i:$i;} printf "\n"}'))
   echo "idascii : $idascii"
   folder=$(echo "$elem" | awk -F 'serial' '{print $(NF-1)}')
   if echo "$fullid" | grep "$id" > /dev/null || echo "$fullid" | grep "$idascii" > /dev/null
   then
      echo "OK : $folder"
      break;
   fi
   
done

exit
