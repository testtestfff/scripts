#!/bin/bash

liste1=( `cat $1 `)
liste2=( `cat $2 `)
found=false
count=0

for ip1 in "${liste1[@]}"
do
   found=false
   for ip2 in "${liste2[@]}"
   do
      if [[ $ip1 == $ip2 ]]
      then
         found=true
         break
      fi
   done
   if ! $found
   then
      echo $ip1" pas trouve"
      echo $ip1 >> ip_not_found.txt
      count=`expr $count + 1`
   fi
done

echo $count" IP non trouvees"
