#!/bin/bash

logfile=mount.log

sudo ls > /dev/null

while true
do
   if [ -z "$(mount | grep $(readlink -f /dev/disk/by-uuid/6F5478D00B2E51F2))" ]
   then
      (echo $(date +%Y-%m-%d\ %H:%M:%S) : mount 6F5478D00B2E51F2) >> $logfile
      if [ ! -d /media/6F5478D00B2E51F2 ]
      then
         sudo mkdir /media/6F5478D00B2E51F2
      fi
      sudo mount -U 6F5478D00B2E51F2 /media/6F5478D00B2E51F2
   fi
   if [ -z "$(mount | grep $(readlink -f /dev/disk/by-uuid/57CA474F45B314AC))" ]
   then
      (echo $(date +%Y-%m-%d\ %H:%M:%S) : mount 57CA474F45B314AC) >> $logfile
      if [ ! -d /media/57CA474F45B314AC ]
      then
         sudo mkdir /media/57CA474F45B314AC
      fi
      sudo mount -U 57CA474F45B314AC /media/57CA474F45B314AC
   fi
   sleep 1s
done
