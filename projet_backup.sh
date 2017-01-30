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


Package=('dialog' 'xdialog' 'rsync' 'openssh' 'sshfs') 
# echo ${Package[@]}
checkPackageInstalled ${Package[@]}

function installPackage() {
    for i in $1; do
        checkDistib
        echo "Installation de $i"
        if [[ ${OS} == "Debian" ]]; then
            x=`sudo apt-get install $i 2>/dev/null`
        elif [[ ${OS} == "Ubuntu" ]]; then
            x=`sudo apt-get install $i 2>/dev/null`
        elif [[ ${OS} == "ManjaroLinux" ]]; then
            x=`sudo pacman -S $i 2>/dev/null`
        elif [[ ${OS} == "Arch" ]]; then
            x=`sudo pacman -S $i 2>/dev/null`
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

function msgBox() {
    $DIALOG --title "$1" --msgbox "$2" 20 60
}

function passBox() {
    fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/projet$$
    trap "rm -f $fichtemp" 0 1 2 5 15
    # get password
    $DIALOG --title "Password" \
        --clear \
        --passwordbox "Je vais avoir besoin de ton mot de passe\npour pouvoir continuer le programme." 20 60 2> $fichtemp

    ret=$?

    # make decision
    case $ret in
        0)
            passwordUser=`cat $fichtemp`;;
        1)
            echo "Cancel pressed." && exit;;
        255)
           exit;;
    esac
}

passBox

function bonjour() {
    $DIALOG --title "Bonjour $(whoami)" --clear \
        --yesno "Bonjour $(whoami), comment vas tu?\n\nAlors comment ça tu veux faire un backup ?" 20 60

    case $? in
        0)	echo "Oui choisi. ";;
        1)	echo "Non choisi. " && exit;;
        255)	echo "Appuyé sur Echap. " && exit;;
    esac
}

bonjour

function backupDir() {
    fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/projet$$
    trap "rm -f $fichtemp" 0 1 2 5 15
    $DIALOG --clear --title "Backup Choice" \
        --menu "Bonjour $(whoami) : Que souhaitez vous faire?" 20 100 4 \
        "LocalToLocal" "Sauvegarder source local sur destination locale" \
        "LocalToDistant" "Sauvegarder source local sur destination distante" \
        "DistantToDistant" "Sauvegarder source distante sur destination distante" \
        "DistantToLocal" "Sauvegarder source distante sur destination locale" 2> $fichtemp
    valret=$?
    choix_backupDir=`cat $fichtemp`
    case $valret in
        0)	echo "'$choix_backupDir' est choix";;
        1) 	echo "Appuyé sur Annuler.";;
        255) 	echo "Appuyé sur Echap.";;
    esac
}

function backup() {
    fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/projet$$
    trap "rm -f $fichtemp" 0 1 2 5 15
    $DIALOG --clear --title "Backup Choice" \
        --menu "Bonjour $(whoami) : Que souhaitez vous faire?" 20 100 4 \
        "LocalToLocal" "Sauvegarder source locale sur destination locale" \
        "LocalToDistant" "Sauvegarder source locale sur destination distante" \
        "DistantToDistant" "Sauvegarder source distante sur destination distante" \
        "DistantToLocal" "Sauvegarder source distante sur destination locale" 2> $fichtemp
    valret=$?
    choix_backup=`cat $fichtemp`
    case $valret in
        0)	echo "'$choix_backup' est choix";;
        1) 	echo "Appuyé sur Annuler.";;
        255) 	echo "Appuyé sur Echap.";;
    esac
}

backupDir
backup
echo $choix_backup


function choiceFolder() {
    folder=`$DIALOG --stdout --title "Choisissez un dossier" --fselect $HOME/ 60 150`

    if [[ $1 == "sourceFolderLocal" ]]; then
        sourceFolderLocal=$folder
    elif [[ $1 == "distantFolderLocal" ]]; then
        distantFolderLocal=$folder
    fi

    case $? in
        0)
            echo "\"$folder\" choisi";;
        1)
            echo "Appuyé sur Annuler.";;
        255)
            echo "Fenêtre fermée.";;
    esac
}

# choiceFolder "sourceFolderLocal"
# choiceFolder "distantFolderLocal"
# echo $sourceFolderLocal
# echo $distantFolderLocal


function connectSshfs() {
    fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/projet$$
    trap "rm -f $fichtemp" 0 1 2 5 15
    if [[ $1 == "Password" ]]; then
        $DIALOG --title "$1" --clear \
            --passwordbox "$2:" 16 51 2> $fichtemp
    else
        $DIALOG --title "$1" --clear \
            --inputbox "$2:" 16 51 2> $fichtemp
    fi

    valret=$?

    case $valret in
        0)
            echo "`cat $fichtemp`";;
        1)
            echo "";;
        255)
            if test -s $fichtemp ; then
                cat $fichtemp
            else
                echo ""
            fi
            ;;
    esac
}

function checkIfDistantFolderIsMount() {
    mount=`ls $1 2>/dev/null`
    result=$?
    local folder=$1
    echo $result
    if [[ $result -eq 0 ]]; then
        echo "le dossier existe"
        if [ ${#folder[@]} -gt 0 ]; then
            msgBox "Info Démontage" "On démonte le dossier $folder, s'il n'est pas fait"
            `echo $passwordUser | sudo -S umount $1`
        fi
    else
        echo "le dossier n'existe pas"
        mk=`mkdir $1`
        result=$?
        if [[ $result != 0 ]]; then
            echo "Vérifie tes droits dans le dossier ou te trouve afin de créer un répertoire"
        else
            echo "le dossier distantFolder a bien été créé"
        fi
    fi

    port=`connectSshfs "Port" "Donner votre port de connection en ssh"`
    name=`connectSshfs "Name" "Donner votre nom de connection en ssh"`
    host=`connectSshfs "Host" "Donner votre adresse de connection en ssh"`
    folder=`connectSshfs "Folder" "Donner votre dossier de connection en ssh"`
    pass=`connectSshfs "Password" "Donner votre mot de passe de connection en ssh"`

    echo "$port"

    if [[ $port != "" && $name != "" && $host != "" && $folder != "" ]]; then
        mount=`echo $pass | sshfs -p$port $name@$host:$folder $1 -o password_stdin`
        echo $mount
    fi
    # Il faut gérer les erreurs de sshfs
}

checkIfDistantFolderIsMount "distantFolderOne"
checkIfDistantFolderIsMount "distantFolderTwo"

function choiceFolderDistant() {
    folder=`$DIALOG --stdout --title "Choisissez un dossier" --fselect $HOME/ 60 150`

    if [[ $1 == "sourceFolderLocal" ]]; then
        sourceFolderLocal=$folder
    elif [[ $1 == "distantFolderLocal" ]]; then
        distantFolderLocal=$folder
    fi

    case $? in
        0)
            echo "\"$folder\" choisi";;
        1)
            echo "Appuyé sur Annuler.";;
        255)
            echo "Fenêtre fermée.";;
    esac
}

# umount=`umount distantFolderOne & umount distantFolderTwo & sudo rm -R sourceFolderOne sourceFolderTwo`
