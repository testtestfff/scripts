#!/bin/bash

re='^[0-9]+$'
i=0
current=0
somme=0
while read line
do
   if [[ $line =~ $re ]]
   then
      i=$(($i+1))
      somme=$(($somme+$line))
   fi
done < temp.log
moyenne=$(($somme/$i))
echo "moyenne = "$moyenne

