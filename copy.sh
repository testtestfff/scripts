#!/bin/bash

#FIXME : en cas d'erreur fatala, loguer un df global, un mount, chercher si la partition sd1  par exemple est montée ailleurs
# que prévu, de maniere generale, mettre un flag KO et une fonction finalize
# si KO, alors démonter X fois remonter, et recommencer en récursif
# TODO commenter ici

usage="$(basename "$0") [-s fichier] [-d fichier] [-f fichier] [-b nombre] [-B] [-r] [-v] [-V] [-c] [-m] [-h]\nProgramme  permettant de copier un fichier ou dossier source vers un dossier de destination.\nL'interet de ce script est qu'il permet de copier def fichiers partiellement et qu'il peut etre interrompu pour reprendre plus tard sans repartir a zero.\nDe plus, si la source ou la destination se trouve sur un peripherique USB, en cas d'erreur de transfert, le script reinitialise automatiquement la connexion avec le peripherique pour poursuivre la copie sans perte de donnee.\nOn peut specifier la taille d'un bloc en octets ou laisser le programme la calculer.\nOn peut egalement choisir entre un traitement iteratif ou recursif des dossiers. Ce dernier est plus long pour une copie complete mais bien plus rapide lorsqu'une partie des dossiers a deja ete copiee.\nDescription des paramètres :\n
    -s  definit le chemin du fichier ou repertoire source\n
    -d  definit le chemin du fichier ou repertoire de destination\n
    -f  fichier pour enregistrer les logs a la place de stdout\n
    -b  specifie la taille d'un bloc en octets\n
    -B  indique qu'on stoppe en cas d'echec sur un fichier au lieu de passer au suivant
    -r  indique un traitement recursif\n
    -v  mode verbeux\n
    -V  mode verbeux max\n
    -c  pour effectuer une copie\n
    -m  pour effectuer un deplacement\n
    -h  affiche l'aide"


# sudo bidon pour eviter de saisir le mot de passe plus tard
sudo ls > /dev/null

# date debut en nanosecondes
debut=$(date +%s)

# blocksize par defaut : 512 Ko
DEFAULT_BLOCKSIZE=524288
# skip block par defaut : 0
DEFAULT_SKIP_BLOCKS=0
# attente par défaut
WAIT_DEFAULT=7s
# attente avant mount
WAIT_BEFORE_REMOUNT=3s
# attente entre 2 tentatives de communication avec le disque
WAIT_FIX_DEVICE=5s
# attente apres debranchement USB
WAIT_USB_OFF=5s
# attente apres rebranchement USB
WAIT_USB_ON=10s
# nombre de tentatives de mount
MAX_REMOUNT_ATTEMPTS=3
# nombre de tentatives de communication avec le disque
MAX_FIX_DEVICE_ATTEMPTS=4
# nombre de tentatives de copies par fichier
MAX_COPY_ATTEMPTS=30
# sauvegarde de IFS et redefinition
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

# definition des variables
verbose=false
fullVerbose=false
logToFile=false
recursive=false
logConsole=false
skipFile=true
action="copy"

#######################################################################################################
# LECTURE DES PARAMETRES ET INITIALISATION
#######################################################################################################

# si aucun parametre n'est renseigne on affiche l'aide
if [ $# -eq 0 ]
then
   echo "$usage"
   IFS=$SAVEIFS
   exit 1
fi

#TODO ajouter un param pour silent, comportement en cas de pb : skip ?
# lecture des parametres passes en entree
while getopts s:d:f:b:BrvVcmh opts; do
   case ${opts} in
      s) 
         source=${OPTARG} ;;
      d) 
         dest=${OPTARG} ;;
      f)
         logToFile=true;
         logFile=${OPTARG} ;;
      b)
         BLOCKSIZE=${OPTARG} ;;
      B)
         skipFile=false ;;
      r)
         recursive=true ;;
      v) 
         verbose=true ;;
      V) 
         fullVerbose=true ;;
      c)
         action="copy" ;;
      m)
         action="move" ;;
      h) 
         echo -e $usage
         IFS=$SAVEIFS
         exit 0;;
      *) 
         echo -e $usage
         IFS=$SAVEIFS
         exit 0;;
   esac
done


# reinitialisation du fichier de log
if ($logToFile)
then
   if [ -f $logFile ]
   then
      rm $logFile
   fi
   touch "$logFile"
   exec &> "$logFile"
   # on recupere le chemin complet du fichier
   logFile=$(readlink -e "$logFile")
fi

if [ -n "$source" ] && [ -n "$dest" ]
then
   echo "source : "$source
   echo "dest : "$dest
else
   echo "source ou dest manquant, erreur"
   IFS=$SAVEIFS
   exit 1
fi

#######################################################################################################
# DEFINITION DES FONCTIONS
#######################################################################################################

# cette fonction permet d'ecrire les logs dans un fichier ou dans la console, en incluant la date
function log() {
   if ($logToFile)
   then
      #/bin/echo [$(date +%Y-%m-%d\ %H:%M:%S:%N | cut -c -23)] "$1" | tee -a "$logFile"
      /bin/echo [$(date +%Y-%m-%d\ %H:%M:%S:%N | cut -c -23)] "$1" >> "$logFile"
   else
      /bin/echo [$(date +%Y-%m-%d\ %H:%M:%S:%N | cut -c -23)] "$1"
   fi
}

# Cette fonction calcule et affiche le temps ecoule entre les 2 dates passees en parametres
function dureetotale() {
   dt=$(($2 - $1))
   ds=$((dt % 60))
   dm=$(((dt / 60) % 60))
   dh=$((dt / 3600))
   log $(printf "duree totale : %02d:%02d:%02d\n" $dh $dm $ds)
}

# Cette fonction determine le port USB sur lequel est branche le peripherique contenant la partition passee en parametre
# Pour le parametre, par exemple, si le FS est /dev/sde1 alors le parametre est sde1
function getDeviceBus() {

   log "      getDeviceBus arg=$1"
   # on extrait la chaine correspondant a l'identifiant technique du peripherique
   fullid=$(ls -al "/dev/disk/by-id/" | grep "$1" | awk -F ' -> ' '{print $(NF-1)}')
   log "      fullid : $fullid"
   # cette boucle parcourt les dossiers des peripheriques USB et extrait le numero de serie pour chaque element trouve
   for elem in $(find /sys/bus/usb/devices/usb*/ -maxdepth 12 -name "serial" -type f | awk '{for (i=1; i<=NF; i++){printf $i";"; system("cat " $i);}}')
   do
      # recuperation du numero de serie contenu dans le fichier serial
      id=$(echo "$elem" | awk -F ';' '{print $NF}' | sed -e 's/^ *//' -e 's/ *$//')
      $fullVerbose && log "      numero de serie du peripherique usb : $id"
      # conversion en ASCII du numero de serie car il est parfois en hexa
      idascii=$(echo -e $(echo "$id" | awk -F '' '{for (i=1; i<=NF; i++) { printf (i%2 == 1) ? "\\x"$i:$i;} printf "\n"}' | sed -e 's/^ *//' -e 's/ *$//'))
      $fullVerbose && log "      idascii : $idascii"
      # chemin du dossier en cours
      folder=$(echo "$elem" | awk -F 'serial' '{print $(NF-1)}')
      $fullVerbose && log "      folder : $folder"
      # si l'identifiant technique contient le numero de serie en cours alors on a trouve
      if (echo "$fullid" | grep "$id" > /dev/null) || ([ ! -z "$idascii" ] && echo "$fullid" | grep "$idascii" > /dev/null)
      then
         $verbose && log "         dossier du bus usb a redemarrer : $folder"
         result=$(echo "$folder" | awk -F '/' '{print $(NF-1)}')
         log "         port usb : $result"
         return
      fi
   done

   # si rien faire un lshw -businfo et chercher le port usb de la partition
   log "      on ne trouve pas le port usb avec la recherche par serial, on recherche avec lshw"
   result=$(sudo lshw -businfo | grep -B 1 -m 1 $(echo "$1" | cut -c -3) | head -n 1 | awk '{print $1}' | cut -c 5- | tr ":" "-")
   #FIXME : verifier que ca commence par USB...
   if [ -z "$result" ]
   then
      log "      port non trouve"
   else
      log "      port : $result"
   fi

}

# Cette fonction determine le port USB sur lequel est branche le peripherique contenant le fichier passe en parametre
function getDeviceFolder() {

   #TODO ne pas psaser le mount point en param mais le source complet pour eviter de faire 2 fois "df"
   log "   getDeviceFolder arg=$1"
   # extraction de la partition
   partition=$(df "$1" | tail -1 | awk '{print $1}')
   arg=$(echo "$partition" | awk -F '/' '{print $NF}')
   # appel de la fonction pour trouver le port usb
   getDeviceBus "$arg"
   # si la fonction precedente n'a pas permis de trouver il s'agit peut etre d'un raid ?
   if [ -z "$result" ]
   then
      # vide, on teste raid
      portList=""
      pList=$(cat /proc/mdstat | grep $(echo "$partition" | cut -c 6-) | awk '{for (i=NF; i>=1; i--) {if(match($i, "raid")) break; printf substr($i,0,4)"\n";} printf "\n"}')
      for part in $pList
      do
         log "   $part"
         getDeviceBus "$part"
         portList="$result $portList"
      done
      result="$portList"
      log "   port : $result"
   else
      log "   port : $result"
   fi

}

function resetUSB() {

   log "            resetUSB - port du bus usb a redemarrer : $1"
   log "            stop..."
   
   echo "$1" | sudo tee /sys/bus/usb/drivers/usb/unbind
   log "            attente $WAIT_USB_OFF avant rebranchement"
   sleep $WAIT_USB_OFF
   log "            start..."
   echo "$1" | sudo tee /sys/bus/usb/drivers/usb/bind
   log "            attente $WAIT_USB_ON avant de reprendre la suite du traitement"
   sleep $WAIT_USB_ON
   log "            on tente de reveiller les peripheriques avec un lshw"
   sudo lshw -businfo > /dev/null 2>&1

}

# cette fonction est appelee en premier en cas d'erreur de copie
# elle fait le necessaire pour qu'en retour les peripheriques soient presents
function fixDevices() {

   log "      on tente de reveiller les peripheriques avec un lshw"
   sudo lshw -businfo > /dev/null 2>&1

   # on traite le disque source
   log "      traitement du disque source de label $source_label"
   fixDevice "$source_label" "$source_port"

   # on traite le disque dest
   log "      traitement du disque destination de label $dest_label"
   fixDevice "$dest_label" "$dest_port"

}


function fixDevice() {

   #FIXME TODO il se peut que le disque 58D869BD7CE2D99A n'apparaisse pas dans by-label mais seulement dans by-uuid
   #TODO revoir la sequence, l'ordre des operations et l'attente, et traiter le cas port vide
   log "         test de la presence du disque de label $1"
   for i in $(seq 1 $MAX_FIX_DEVICE_ATTEMPTS)
   do
      sleep $WAIT_FIX_DEVICE
      # on teste la presence du disque
      if $(ls "/dev/disk/by-label/$1" > /dev/null 2>&1) || $(ls "/dev/disk/by-uuid/$1" > /dev/null 2>&1)
      then
         log "         disque de label $1 operationnel"
         return
      else
         log "         disque de label $1 non trouve lors de la tentative $i sur $MAX_FIX_DEVICE_ATTEMPTS"
         # avant le dernier passage
         if (($i == $MAX_FIX_DEVICE_ATTEMPTS-1))
         then
            # on n'a toujours pas trouve la partition, on tente un reset
            log "         impossible de trouver la partition pour le label $1, on tente un reset"
            resetUSB "$2"
            log "         reset effectue, on teste si la partition pour le label $1 est retrouvee"
         fi
      fi
      $verbose && log "         on attend $WAIT_FIX_DEVICE"
      
   done

   log "         le peripherique de label $1 ne repond pas malgre le reset, on abandonne definitivement"
   IFS=$SAVEIFS
   exit 1
}

function fixFS() {

   #TODO pourquoi boucler ?
   for i in $(seq 1 $MAX_REMOUNT_ATTEMPTS)
   do
      # test si le mount point est OK
      log "      on verifie que $1 est toujours un mount point"
      if $(mountpoint -q "$1")
      then
         log "      $1 est bien un mount point, on fait un df du contenu pour valider le mount point"
         if $(df $1/* > /dev/null 2>&1)
         then
            log "      mount point $1 OK"
            return
         fi
      fi

      # si on arrive ici alors le mount point est KO
      log "      $1 n'est pas un mount point valide"
      log "      on tente de demonter l'ancien mount point"
      currentDir=$(pwd)
      cd "/tmp"
      for mountCount in $(seq 1 $(mount | grep -c "$1"))
      do
         log "      tentative de demontage de $1 numero $mountCount"
         sudo umount "$1" > /dev/null
      done
      
      log "      on tente de creer le dossier du mount point $1"
      sudo mkdir "$1" > /dev/null
      log "      tentative de mount du label $2 sur le mount point $1"
      if $(sudo mount -L "$2" "$1")
      then
         log "      mount OK"
         cd "$currentDir"
         return
      fi
      log "      mount KO lors de la tentative $i sur $MAX_REMOUNT_ATTEMPTS"
      sleep "$WAIT_BEFORE_REMOUNT"
   done

   # on abandonne
   log "      abandon"
   IFS=$SAVEIFS
   exit 1

}

function copy() {
   sudo whoami > /dev/null
   index=0
   while (($index < $MAX_COPY_ATTEMPTS))
   do
      $verbose && log "   copy() - index : $index"
      if [ -f "$2" ]
      then
         $verbose && log "   le fichier $2 existe : on calcule le blocksize et les blocs a skipper"
         size_source=$(du -b "$1" | cut -f 1)
         $verbose && log "   size_source = $size_source"
         case ${#size_source} in
         1)
            BLOCKSIZE=1 ;;
         2) 
            BLOCKSIZE=8 ;;
         3)
            BLOCKSIZE=64 ;;
         4) 
            BLOCKSIZE=512 ;;
         5) 
            BLOCKSIZE=8192 ;;
         6)
            BLOCKSIZE=65536 ;;
         7)
            BLOCKSIZE=524288 ;;
         8)
            BLOCKSIZE=8388608 ;;
         9)
            BLOCKSIZE=67108864 ;;
         10)
            BLOCKSIZE=67108864 ;;
         11)
            BLOCKSIZE=67108864 ;;
         12)
            BLOCKSIZE=67108864 ;;
         13)
            BLOCKSIZE=67108864 ;;
         esac
         
         size_b=$(stat -c "%s" "$2")
         $verbose && log "   size_b = $size_b"
         skip_blocks=$((size_b / BLOCKSIZE))
      else
         $fullVerbose && log "   le fichier $2 n'existe pas : blocksize et skip_blocks par defaut"
         #BLOCKSIZE=16384
         BLOCKSIZE=$DEFAULT_BLOCKSIZE
         #BLOCKSIZE=8388608
         skip_blocks=$DEFAULT_SKIP_BLOCKS
      fi
      index=$(($index+1))
      $verbose && log "   blocksize = $BLOCKSIZE"
      
      dd if="$1" of="$2" skip=$skip_blocks seek=$skip_blocks obs=$BLOCKSIZE ibs=$BLOCKSIZE > /dev/null 2>&1
      # on recupere le statut de la derniere commande
      if [ $? -eq 0 ]
      then
         # la copie s'est bien passee
         $fullVerbose && log "   copie OK"
         return
      else
         # la copie a echoue
         #TODO traiter le cas des liens symlink et skipper


         log "   copie KO - appel de fixDevices"
         fixDevices

         # positionner FSChanged
         log "   appel de fixFS pour source"
         fixFS "$source_mount_point" "$source_label"

         log "   appel de fixFS pour dest"
         fixFS "$dest_mount_point" "$dest_label"

         log "   on se replace dans le repertoire de base"
         cd "$source"
         

      fi
   done
   
   log "   echec apres $MAX_COPY_ATTEMPTS tentatives de copie pour le fichier $1"
   if ($skipFile)
   then
      log "   on passe au fichier suivant"
   else
      log "   on abandonne"
      IFS=$SAVEIFS
      exit 1
   fi
}


function processElement() {
   $fullVerbose && log "processElement arg1 : $1 - arg2 : $2"
   for file in $(find "$1" -maxdepth 1)
   do
      $fullVerbose && log "fichier en cours : $file"
      if [[ -d "$file" ]]
      then
         $fullVerbose && log "$file est un repertoire"
         if [ "$file" == "$1" ]
         then
            $fullVerbose && log "fichier racine, on passe"
            continue
         fi
         suffix=$(echo "$file" | awk -F $source '{print $NF}')
         $fullVerbose && log "suffix : $suffix"
         newdir="$dest$suffix"
         if [ ! -d "$newdir" ]
         then
            $fullVerbose && log "$newdir n'existe pas on le cree"
            mkdir "$newdir"
         else
            $fullVerbose && log "$newdir existe"
            sizesource=$(ls -alR "$file"/ | grep -v '^d' | awk '{total += $5} END {print total}')
            sizedest=$(ls -alR "$newdir"/ | grep -v '^d' | awk '{total += $5} END {print total}')
            if [[ "$sizesource" == "$sizedest" ]]
            then
               $fullVerbose && log "dossiers identiques, on passe au suivant"
               continue
            else
               $fullVerbose && log "dossiers differents, on copie"
            fi
         fi
         $fullVerbose && log "appel process $file - $dest$suffix"
         processElement "$file" "$dest$suffix"
      else
         if [[ -f "$file" ]]
         then
            $fullVerbose && log "$file est un fichier"
            suffix=$(echo "$file" | awk -F $source '{print $NF}')
            newfile="$dest$suffix"
            if [ ! -f "$newfile" ]
            then
               $fullVerbose && log "$newfile n'existe pas"
               $fullVerbose && log "nouveau fichier a copier = $newfile"
            else
               $fullVerbose && log "$newfile existe"
               sizesource=$(du -b "$file" | cut -f 1)
               sizedest=$(du -b "$newfile" | cut -f 1)
               if [[ "$sizesource" == "$sizedest" ]]
               then
                  $fullVerbose && log "fichiers identiques, on passe au suivant"
                  continue
               else
                  $fullVerbose && log "fichiers differents, on copie"
               fi
            fi
            copy "$file" "$dest$suffix"
         else
            log "erreur : fichier $file indetermine"
         fi
      fi
   done
}

function recursiveProcessing() {
   processElement "$1" "$2"
}

function iterativeProcessing() {
   for file in $(find .)
   do
      #$fullVerbose && log "on se place dans $newsource"
      $fullVerbose && log "fichier en cours : $file"
      if [[ -d "$file" ]]
      then
         $fullVerbose && log "$file est un repertoire"
         newdir="$2/$file"
         $fullVerbose && log "nouveau repertoire a creer = $newdir"
         if [ ! -d "$newdir" ]
         then
            $fullVerbose && log "$newdir n'existe pas on le cree"
            mkdir "$newdir"
         else
            $fullVerbose && log "$newdir existe"
         fi
      else
         if [[ -f "$file" ]]
         then
            $fullVerbose && log "$file est un fichier"
            newfile="$2/$file"
            if [ ! -f $newfile ]
            then
               $fullVerbose && log "$newfile n'existe pas"
               $fullVerbose && log "nouveau fichier a copier = $newfile"
            else
               $fullVerbose && log $newfile" existe"
               sizesource=$(du -b "$1/$file" | cut -f 1)
               sizedest=$(du -b "$newfile" | cut -f 1)
               if ((sizesource == sizedest))
               then
                  $fullVerbose && log "fichiers identiques, on passe au suivant"
                  continue
               else
                  $fullVerbose && log "fichiers differents, on copie"
               fi
            fi
            copy "$1/$file" "$newfile"
         else
            #FIXME pb : essayer de démonter et remonter
            log "$file est indetermine"
         fi
      fi
   done
}

#######################################################################################################
# DEBUT DU TRAITEMENT
#######################################################################################################

if [ ! -d "$dest" ]
then
   log "$dest n'existe pas on le cree"
   mkdir "$dest"
else
   log "$dest existe"
fi

#source_mount_point=$(stat -c '%m' $1)
source_mount_point=$(df "$source" | tail -1 | awk '{ print $6 }')
source_label=$(echo "$source_mount_point" | awk -F "/" '{print $NF}') 
dest_mount_point=$(df "$dest" | tail -1 | awk '{ print $6 }')
dest_label=$(echo "$dest_mount_point" | awk -F "/" '{print $NF}')
getDeviceFolder "$source_mount_point"
source_port="$result"
source_partition="$partition"
result=""
partition=""
getDeviceFolder "$dest_mount_point" 
dest_port="$result"
dest_partition="$partition"
newsource=$source
newdest=$dest

log "source mount point : $source_mount_point"
log "source label : $source_label"
log "dest mount point : $dest_mount_point"
log "dest label : $dest_label"
log "source port : $source_port"
log "dest port : $dest_port"
log "source partition : $source_partition"
log "dest partition : $dest_partition"

if [[ -d "$source" ]]
then
   $fullVerbose && log "$source est un repertoire"
   #TODO ICI SWITCHER POUR APPELER RECURSIF OU NON
   cd "$source"
   if ($recursive)
   then
      $verbose && log "traitement recursif"
      recursiveProcessing "$source" "$dest"
   else
      $verbose && log "traitement iteratif"
      iterativeProcessing "$source" "$dest"
   fi
else 
   if [[ -f "$source" ]]
   then
      $fullVerbose && log "file"
      destfile="$dest/$(echo $source | awk -F '/' '{print $NF}')"
      $fullVerbose && log "destfile : $destfile"
      $fullVerbose && log "appel de copy $source - $destfile"
      copy "$source" "$destfile"
   fi
fi

fin=$(date +%s)
dureetotale $debut $fin
IFS=$SAVEIFS


#######################################################################################################
# morceaux de code en commentaire pouvant etre utiles un jour ou l'autre ...
#######################################################################################################

# pour le resetUSB
#sudo bash -c "echo 0 > \"$1\"authorized"
#sudo bash -c "echo 1 > \"$1\"authorized"

# pour demander confirmation avant exit ou continuer
#while true; do
#    read -p "Voulez-vous lancer l'attaque ? (O/N)" yn
#    case $yn in
#        [Oo]* ) break;;
#        [Nn]* ) exit 0;;
#        * ) echo "entrez O ou N";;
#    esac
#done

# pour voir le déroulement du dd
#pv -tpreb "$1" | dd of="$2" skip=$skip_blocks seek=$skip_blocks bs=$BLOCKSIZE

# pour trouver le port USB :
# sudo lshw -businfo | grep -B 1 -m 1 "sdg" | head -n 1 | awk '{print $1}' | cut -c 5- | tr ":" "-"


# une seule commande pour effectuer resetUSB si on ne trouve pas le disque
# ls /dev/disk/by-label/multimedia1 > /dev/null 2>&1 || reset USB

      # (mountpoint -q "$1" && df "$1/*" > /dev/null 2>&1) || ((umount "$1" > /dev/null 2>&1 || true)
      # && (mkdir "$1" > /dev/null 2>&1 || true) && mount -L "$2" "$1")

# affiche le bus en fonction d'un fichier
# find /sys/bus/usb/devices/usb*/ -maxdepth 12 -name serial | awk -F '\n' '{for(i=1; i<=NF; i++){print $i; system("cat " $i)}}' | tr "\\n" ";" | awk -F ';' -v idtech="$(ll /dev/disk/by-id | grep $(df /media/multimedia2 | tail -1 | awk -F ' ' '{print $1}' | awk -F '/' '{print $NF}') )" '{for(i=1; i<=NF; i++){if (i%2==0 && match(idtech,$i)){printf $(i-1);break;}}printf "\n" }' | sed 's/serial//' | awk -F '/' '{printf $(NF-1)"\n"}'

# hexa to decimal conversion :echo "ibase=16; FF" | bc
# decimal to hexa : echo "obase=16; 34" | bc

# On accède à chaque champs de l'enregistrement courant par la variable $1, $2, ... $NF. 
# $0 correspond à l'enregistrement complet. La variable NF contient le nombre de champs de l'enregistrement courant, 
# la variable $NF correspond donc au dernier champ.



