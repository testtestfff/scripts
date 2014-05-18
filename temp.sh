#!/bin/bash

#max_mega=2
#max_bytes=$(($max_mega*1024*1024))

max_kilo=256
max_bytes=$(($max_kilo*1024))
echo "max_bytes = $max_bytes"
# si le fichier de log n'existe pas on le cree
if [ ! -f temp.log ]
then
   touch temp.log
fi

while true
do
   while [ $(du -b temp.log | cut -f 1) -le "$max_bytes" ]
   do
      (date && nvidia-settings -q alex-G73Sw:0[gpu:0]/gpucoretemp[0] -t) >> $HOME/scripts/temp.log
      sleep 1m
   done
   mv temp.log temp-$(date +%Y-%m-%d-%H-%M-%S).log
   touch temp.log
done
