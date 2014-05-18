#!/bin/bash

function checkIfHostsAlive() {

   echo "checkIfHostAlive() arg=$1"
   alive=false
      host=$1
      echo "host : $host"
      echo [$(date +%Y-%m-%d\ %H:%M:%S:%N | cut -c -23)] "tests arg=$host"
      alive=false
      #result=$(curl -m 5 --retry 2 --retry-delay 1 --head "$host" 2>&1)
      echo "premier test"
      result1=$(curl http://www.isitdownrightnow.com/check.php?domain=$(echo $host | cut -c 5-) | grep "UP")
      status1=$?
      echo "second test"
      result2=$(curl http://www.downforeveryoneorjustme.com/$host | grep "is up")
      status2=$?
      echo "status1 : $status1"
      echo "status2 : $status2"
      if [ $status1 -eq 0 ] || [ $status2 -eq 0 ]
      then
         echo [$(date +%Y-%m-%d\ %H:%M:%S:%N | cut -c -23)] "host $host is alive"
         alive=true
         echo "envoi mail"
         echo "host $host is alive" | mail -s "alarmUp" xxx@xxx.xx
      fi
      echo [$(date +%Y-%m-%d\ %H:%M:%S:%N | cut -c -23)] "host $host is down"
      alive=false

}

alive=false

      while true
      do
         checkIfhostsAlive $1
         if $alive
         then
            echo "host is up"
            break
         else
            echo "host is down"
         fi
         attente=$((RANDOM % 60 + 60))
         echo "on attend $attente s"
         sleep $attente
      done
