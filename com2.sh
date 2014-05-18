

# affiche le bus en fonction d'un fichier
# find /sys/bus/usb/devices/usb*/ -maxdepth 12 -name serial | awk -F '\n' '{for(i=1; i<=NF; i++){print $i; system("cat " $i)}}' | tr "\\n" ";" | awk -F ';' -v idtech="$(ll /dev/disk/by-id | grep $(df /media/multimedia2 | tail -1 | awk -F ' ' '{print $1}' | awk -F '/' '{print $NF}') )" '{for(i=1; i<=NF; i++){if (i%2==0 && match(idtech,$i)){printf $(i-1);break;}}printf "\n" }' | sed 's/serial//' | awk -F '/' '{printf $(NF-1)"\n"}'

sudo lshw -businfo | grep -B 1 -m 1 "sdg" | head -n 1 | awk '{print $1}' | cut -c 5- | tr ":" "-"


$(sudo lshw -businfo | grep -B 1 -m 1 $(echo $(df "/media/0AF2108209E826EE/test" | tail -1 | awk '{print $1}' | cut -c 6-8) | cut -c -3) | head -n 1 | awk '{print $1}' | cut -c 5- | tr ":" "-")

df "$1" | tail -1 | awk '{print $1}'
$(echo "$partition" | awk -F '/' '{print $NF}')

alex@alex-G73Sw:~$ df "/media/0AF2108209E826EE/test" | tail -1 | awk '{print $1}' | cut -c 6-8
sdd


$(sudo lshw -businfo | grep -B 1 -m 1 $(echo $(df "/media/0AF2108209E826EE/test" | tail -1 | awk '{print $1}' | cut -c 6-8) | cut -c -3) | head -n 1 | awk '{print $1}' | cut -c 5- | tr ":" "-")


echo $(sudo lshw -businfo | grep -B 1 -m 1 $(df "/media/0AF2108209E826EE/test" | tail -1 | awk '{print $1}' | cut -c 6-8) | head -n 1 | awk '{print $1}' | cut -c 5- | tr ":" "-") | sudo tee /sys/bus/usb/drivers/usb/unbind

echo $(sudo lshw -businfo | grep -B 1 -m 1 $(df "/path/to/file" | tail -1 | awk '{print $1}' | cut -c 6-8) | head -n 1 | awk '{print $1}' | cut -c 5- | tr ":" "-") | sudo tee /sys/bus/usb/drivers/usb/unbind

(mountpoint -q "$1" && df "$1/*" > /dev/null 2>&1) || ((umount "$1" > /dev/null 2>&1 || true) && (mkdir "$1" > /dev/null 2>&1 || true) && mount -L "$2" "$1")
(mountpoint -q "/media/0AF2108209E826EE" && df "/media/0AF2108209E826EE/*" > /dev/null 2>&1) || ((umount "/media/0AF2108209E826EE" > /dev/null 2>&1 || true) && (mkdir "/media/0AF2108209E826EE" > /dev/null 2>&1 || true) && mount -L "/dev/sdd1" "/media/0AF2108209E826EE")
(mountpoint -q "/media/0AF2108209E826EE" && df "/media/0AF2108209E826EE/*") || ((umount "/media/0AF2108209E826EE" || true) && (mkdir "/media/0AF2108209E826EE" || true) && mount -L "/dev/sdd1" "/media/0AF2108209E826EE")



