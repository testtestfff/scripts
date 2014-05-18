#!/bin/bash

usage="$(basename "$0") [-c duree] [-f fichier] [-i interface]\nTous ces paramètres sont facultatifs.\nDescription des paramètres :\n
    -c  définit la durée de la capture, une bonne valeur est 15 ou 20s. valeur par défaut : 15s\n
    -f  le fichier qui va contenir la capture. valeur par défaut : capture.txt\n
    -i  fixe l'interface\nExemple d'utilisation : "

capture_duration=20s
file=capture.txt
interface=eth0

# cette fonction attend que l'utilisateur appuie sur entrée avant de continuer
function pause(){
   read -p "$*"
}

# cette fonction teste si un tableau contient un élément
# elle prend 2 paramètres en entrée : l'élément à chercher puis le tableau
# elle retourne 0 si l'élément est présent dans le tableau, 1 sinon
function containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

function min() {
   if [ $1 -le $2 ]
   then
      echo $1
   else
      echo $2
   fi
}

# lecture des paramètres passés en entrée
while getopts c:f:i:h: opts; do
   case ${opts} in
      c) 
         capture_duration=${OPTARG} ;;
      f) 
         file=${OPTARG} ;;
      i)
         interface=${OPTARG} ;;
      h) 
         echo -e $usage
         exit 0;;
      *) 
         echo -e $usage
         exit 0;;
   esac
done

# suppression des anciens fichiers
rm $file

# commande qui sert à faire saisir le mot de passe à l'utilisateur pour éviter qu'il ait à le saisir après
echo "sudo bidon pour saisir le mot de passe"
sudo ls > /dev/null

# capture des paquets et stockage des IP source et destination dans le fichier passé en paramètre. 
# ce fichier contiendra donc une IP par ligne
echo "debut de la capture des paquets"
sudo tcpdump -i $interface -n ip > $file &

# on attend pendant l'intervalle de temps passé en paramètre puis on kill le process tcpdump pour arrêter la capture
echo "attente "$capture_duration
sleep $capture_duration
echo "fin de la capture"
sudo killall tcpdump
sleep 2s

exit
