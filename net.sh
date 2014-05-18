#!/bin/bash

logFile="/home/annie/wifi/wifi.log"
intervalle=10s

function log() {
   echo [$(date +%Y-%m-%d\ %H:%M:%S:%N | cut -c -23)] "$1" | tee -a "$logFile"
}

while true
do
   while [ "$(sudo iw eth1 link | grep Bbox-2D8CA6)" == "" ]
   do
      log "erreur de connexion"
      log "desactivation de eth1..."
      sudo ip link set eth1 down
      log "eth 1 desactive"
      log "arret du NetworkManager..."
      sudo killall NetworkManager
      log "NetworkManager arrete, attente 1s"
      sleep 1s
      log "activation de eth1..."
      sudo ip link set eth1 up
      log "eth1 active, attente 1s"
      sleep 1s
      log "connection a Bbox-2D8CA6..."
      sudo iw dev eth1 connect -w Bbox-2D8CA6
      log "connecte, attente 1s"
      sleep 1s
      log "acquisition de l'adresse IP..."
      sudo dhclient -r eth1
      log "test avec un ping"
      ping -c 1 www.google.com
      if [ $? -eq 0 ]
      then
         log "connexion OK"
         break;
      else
         log "erreur de connexion, on attend 3s et on recommence"
         sleep 3s
      fi
   done
   log "attente $intervalle et on controle de nouveau la connexion"
   sleep $intervalle
done

exit
