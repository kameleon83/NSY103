#!/bin/bash

printf "Bonjour $(whoami)\n"
printf "\n"

function checkDistib() {
    ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

    if [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

# On vérifie si Display est possible ( affichage plus sympathique )
function checkPackageInstalled() {
    for p in $@; do
        # echo $p
        checkDistib
        if [[ ${OS} == "Debian" ]]; then
            x=`dpkg -S $p 2> /dev/null`
        elif [[ ${OS} == "Ubuntu" ]]; then
            x=`dpkg -S $p 2> /dev/null`
        elif [[ ${OS} == "ManjaroLinux" ]]; then
            x=`pacman -Q $p 2> /dev/null`
        elif [[ ${OS} == "Arch" ]]; then
            x=`pacman -Q $p 2> /dev/null`
        fi


        if [[ ! ${x} ]]; then
            # false
            not_installed_package=("${not_installed_package[@]}" "$p")
        fi
    done
}


Package=('dialog' 'xdialog' 'rsync' 'openssh')
# echo ${Package[@]}
checkPackageInstalled ${Package[@]}

function installPackage() {
    for i in $1; do
        checkDistib
        if [[ ${OS} == "Debian" ]]; then
            x=`sudo apt install $i`
        elif [[ ${OS} == "Ubuntu" ]]; then
            x=`sudo apt install $i`
        elif [[ ${OS} == "ManjaroLinux" ]]; then
            x=`sudo pacman -S $i`
        elif [[ ${OS} == "Arch" ]]; then
            x=`sudo pacman -S $i`
        fi
    done
}

installPackage ${not_installed_package[@]}


if [ -z $DISPLAY ]
   then
      DIALOG=dialog
   else
      DIALOG=Xdialog
fi

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$
trap "rm -f $fichtemp" 0 1 2 5 15
$DIALOG --clear --title "Mon chanteur français favori" \
	--menu "Bonjour, choisissez votre chanteur français favori :" 20 51 4 \
	 "Brel" "Jacques Brel" \
	 "Aznavour" "Charles Aznavour" \
 	 "Brassens" "Georges Brassens" \
	 "Nougaro" "Claude Nougaro" \
	 "Souchon" "Alain Souchon" \
	 "Balavoine" "Daniel Balavoine" 2> $fichtemp
valret=$?
choix=`cat $fichtemp`
case $valret in
 0)	echo "'$choix' est votre chanteur français préféré";;
 1) 	echo "Appuyé sur Annuler.";;
255) 	echo "Appuyé sur Echap.";;
esac
