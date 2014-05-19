#!/bin/bash

# calcule la temperature min
# prérequis : utiliser temp.sh pour générer temp.log 

re='^[0-9]+$'
current=0
index=0
while read line
do
   if [[ $line =~ $re ]]
   then
      if (($index == 0))
      then
         current=$line
         index=$(($index+1))
      fi
      if (($line < $current))
      then
         current=$line
      fi
   fi
done < temp.log
echo "min = "$current
exit

