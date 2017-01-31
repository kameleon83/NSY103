#!/bin/bash

# if [ "$EUID" -ne 0 ];then
#     echo "Please run as root"
#     exit
# fi

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

if [ -z $DISPLAY ]
then
    DIALOG=dialog
else
    DIALOG=dialog
fi

function msgBox() {
    $DIALOG --title "$1" --msgbox "$2" 20 60
}

function yesOrNot() {
    $DIALOG --title "$1" --clear \
    --yesno "$2" 20 60

    case $? in
        # 0)	echo "Cool";;
        1)  exit;;
        255)    exit;;
    esac
}

yesOrNot "Hello Guys" "Alors comment ça tu veux faire un backup ?"

function installPackage() {
    for i in $1; do
        checkDistib
        echo "Installation de $i dans 1s"
        sleep 1
        if [[ ${OS} == "Debian" ]]; then
            x=`sudo apt-get --assume-yes install $i 2>/dev/null`
        elif [[ ${OS} == "Ubuntu" ]]; then
            x=`sudo apt-get --assume-yes install $i 2>/dev/null`
        elif [[ ${OS} == "ManjaroLinux" ]]; then
            x=`sudo pacman -S --noconfirm $i 2>/dev/null`
        elif [[ ${OS} == "Arch" ]]; then
            x=`sudo pacman -S --noconfirm $i 2>/dev/null`
        fi
    done
    yesOrNot "Installation Terminée" "Installation terminée de : $1"
}

if [[ ${#not_installed_package[@]} != 0 ]]; then
    installPackage ${not_installed_package[@]}
fi

function backupDir() {
    fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/projet$$
    trap "rm -f $fichtemp" 0 1 2 5 15
    $DIALOG --clear --title "Backup Choice" \
    --menu "Que souhaitez vous faire?" 20 100 4 \
    "LocalToLocal" "Sauvegarder source local sur destination locale" \
    "LocalToDistant" "Sauvegarder source local sur destination distante" \
    "DistantToDistant" "Sauvegarder source distante sur destination distante" \
    "DistantToLocal" "Sauvegarder source distante sur destination locale" 2> $fichtemp
    local valret=$?
    choix_backupDir=`cat $fichtemp`
    case $valret in
        0)	yesOrNot "Choix du type de sauvegarde" "Vous avez choisi : '$choix_backupDir'";;
    esac
}



function choiceFolder() {
    folder=`$DIALOG --stdout --title "Choisissez un dossier $3" --fselect ./$2 20 60`

    if [[ $1 == "sourceFolderLocal" ]]; then
        sourceFolderLocal=$folder
    elif [[ $1 == "destinationFolderLocal" ]]; then
        destinationFolderLocal=$folder
    elif [[ $1 == "sourceFolderDistant" ]]; then
        sourceFolderDistant=$folder
    elif [[ $1 == "destinationFolderDistant" ]]; then
        destinationFolderDistant=$folder
    fi


    case $? in
        0)
        echo "\"$folder\" choisi";;
        1)
        echo "Appuyé sur Annuler." && exit;;
        255)
        echo "Fenêtre fermée." && exit;;
    esac
}

# choiceFolder "sourceFolderLocal"
# choiceFolder "destinationFolderLocal"
# echo $sourceFolderLocal
# echo $destinationFolderLocal


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
    folder=$1
    echo $result
    if [[ $result -eq 0 ]]; then
        echo "le dossier existe $folder"
        if [ ${#folder[@]} -gt 0 ]; then
            msgBox "Info Démontage" "On démonte le dossier $folder, s'il n'est pas fait"
            `sudo umount $folder 2>/dev/null`
        fi
    else
        echo "le dossier n'existe pas"
        local mk=`mkdir $folder`
        result=$?
        if [[ $result != 0 ]]; then
            echo "Vérifie tes droits dans le dossier ou te trouve afin de créer un répertoire"
        else
            echo "le dossier $folder a bien été créé"
        fi
    fi

    port=`connectSshfs "Port" "Donner votre port de connection en ssh"`
    name=`connectSshfs "Name" "Donner votre nom de connection en ssh"`
    host=`connectSshfs "Host" "Donner votre adresse de connection en ssh"`
    dir=`connectSshfs "Folder" "Donner votre dossier de connection en ssh"`
    pass=`connectSshfs "Password" "Donner votre mot de passe de connection en ssh"`

    echo "$port"

    if [[ $port != "" && $name != "" && $host != "" && $dir != "" && $pass != "" ]]; then
        mount=`echo $pass | sshfs -p$port $name@$host:$dir $1 -o password_stdin`
        echo $mount
    fi

    choiceFolder $folder $folder
    # Il faut gérer les erreurs de sshfs
}

function conditionChoice() {
    backupDir
    if [[ $choix_backupDir == "LocalToLocal" ]]; then
        choiceFolder "sourceFolderLocal" "" "Source"
        choiceFolder "destinationFolderLocal" "" "Destination"
    elif [[ $choix_backupDir == "LocalToDistant" ]]; then
        choiceFolder "sourceFolderLocal" "" "Source"
        checkIfDistantFolderIsMount "destinationFolderDistant" "" "Destination"
    elif [[ $choix_backupDir == "DistantToDistant" ]]; then
        checkIfDistantFolderIsMount "sourceFolderDistant" "" "Source"
        checkIfDistantFolderIsMount "destinationFolderDistant" "" "Destination"
    elif [[ $choix_backupDir == "DistantToLocal" ]]; then
        checkIfDistantFolderIsMount "sourceFolderDistant" "" "Source"
        choiceFolder "destinationFolderLocal" "" "Destination"
    fi
}

conditionChoice

function typeBackup() {
    fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/projet$$
    trap "rm -f $fichtemp" 0 1 2 5 15
    $DIALOG --clear --title "Backup type Choice" \
    --menu "2 choix s'offre à toi :" 20 100 4 \
    "Compression" "Créer une archive comme sauvegarde" \
    "Synchronisation" "Créer un dossier avec dedans l'arborescense exact des dossiers et fichiers" 2> $fichtemp
    valret=$?
    choixTypeBackup=`cat $fichtemp`
    case $valret in
        0)	yesOrNot "Choix du type de sauvegarde" "Vous avez choisi : '$choixTypeBackup'";;
    esac
}

function compress() {
    yesOrNot "Compression" "Démarrage de la compression dans 2s après validation de cette fenêtre!"
    sleep 2
    dateAndTime=`date +%d-%m-%Y_%H:%M`
    c=`tar -czvf $2/backup_$dateAndTime.tar.gz $1 2>/dev/null`
    msgBox "Compression Terminée" "Cool, la compression est finie!! :-D\nA bientôt"
}

function sync() {
    yesOrNot "Synchronisation" "Démarrage de la synchronisation dans 2s après validation de cette fenêtre!"
    sleep 2
    c=`rsync -r -l -p -v -t -g -o -D -u $1 $2`
}


function verifTypeBackupChoice() {
    if [[ ${#sourceFolderLocal} > 0 ]]; then
        src=$sourceFolderLocal
    elif [[ ${#sourceFolderDistant} > 0 ]]; then
        src=$sourceFolderDistant
    fi

    if [[ ${#destinationFolderLocal} > 0 ]]; then
        dest=$destinationFolderLocal
    elif [[ ${#destinationFolderDistant} > 0  ]]; then
        dest=$destinationFolderDistant
    fi

    typeBackup
    if [[ $choixTypeBackup == "Compression" ]]; then
        compress $src $dest
    elif [[ $choixTypeBackup == "Synchronisation" ]]; then
        sync $src $dest
    fi

}


verifTypeBackupChoice







# umount=`umount sourceFolderDistant & umount destinationFolderDistant && sudo rm -R sourceFolderDistant destinationFolderDistant`
