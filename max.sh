#!/bin/bash

re='^[0-9]+$'
current=0
while read line
do
   if [[ $line =~ $re ]]
   then
      if (($line > $current))
      then
         current=$line
      fi
   fi
done < temp.log
echo "max = "$current
exit

