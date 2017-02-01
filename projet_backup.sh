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

checkPackageInstalled ${Package[@]}

if [ -z $DISPLAY ]
then
    DIALOG=dialog
else
    DIALOG=Xdialog
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
        msgBox "Installation de $i dans 1s une fois valider"
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
    folder=`$DIALOG --stdout --title "Choisissez un dossier $3" --fselect ./$2 40 80`

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
        yesOrNot "Dossier Choisi" "$folder" && echo "\"$folder\"";;
        1)
        echo "Appuyé sur Annuler." && exit;;
        255)
        echo "Fenêtre fermée." && exit;;
    esac
}


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
        exit;;
        255)
        exit;;
    esac
}

function checkIfDistantFolderIsMount() {
    mount=`ls $1 2>/dev/null`
    result=$?
    folder=$1

    if [[ $result -eq 0 ]]; then
        if [ ${#folder[@]} -gt 0 ]; then
            fus=`fusermount -u $folder 2>/dev/null`
        fi
    else
        local mk=`mkdir $folder`
        result=$?
        if [[ $result != 0 ]]; then
            msgBox "Erreur de droits" "Vérifie tes droits dans le dossier ou te trouve afin de créer un répertoire"
        else
            msgBox "Dossier Créé" "le dossier $folder a bien été créé"
        fi
    fi

    port=`connectSshfs "Port" "Donner votre port de connection en ssh"`
    name=`connectSshfs "Name" "Donner votre nom de connection en ssh"`
    host=`connectSshfs "Host" "Donner votre adresse de connection en ssh"`
    dir=`connectSshfs "Folder" "Donner votre dossier de connection en ssh"`
    pass=`connectSshfs "Password" "Donner votre mot de passe de connection en ssh"`

    if [[ $port != "" && $name != "" && $host != "" && $dir != "" && $pass != "" ]]; then
        mount=`echo $pass | sshfs -p$port $name@$host:$dir $1 -o password_stdin`
        echo $mount
    fi

    choiceFolder $folder $folder $3
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


function deleteFolder() {
    if [[ -d $1 ]]; then
        count=`ls $1 | wc -l`
        if [[ $count == 0 ]]; then
            yesOrNot "Suppression répertoire" "Le répertoire $1 créé\nà bien été démonter\nIl contient : $count fichier\nVeux tu le supprimer ?"
            `rm -R $1`
        else
            msgBox "Erreur suppression" "Il y a une erreur lors\nde la suppression de $1.\nTu dois le faire manuellement avec\n 'rm -r $1'\nAvant vérifie bien qu'il n'y a plus\nde fichiers dedans !!!!!!"
        fi
    fi
}

function umountFolder() {
    if [[ -d $1 ]]; then
        yesOrNot "Démontage répertoire" "Le répertoire $1\ndoit-être démonter\nVeux tu le démonter ?"
        `fusermount -u $1`
        deleteFolder $1
    else
        msgBox "Problème de démontage" "Il y a une erreur lors\ndu démontage de $1.\nTu dois le faire manuellement avec\n 'fusermount -u $1'"
    fi
}

function end() {
    if [[ -d "sourceFolderDistant" ]]; then
        umountFolder "sourceFolderDistant"
    elif [[ -d "destinationFolderDistant" ]]; then
        umountFolder "destinationFolderDistant"
    fi
}

function checkErrors() {
    err=`wc -l $1 | sed -e 's/[a-z _.]//g' | bc`
    if [[ $err -gt 1 ]]; then
        $DIALOG --begin 15 10 --tailbox $1  20 125
    else
        msgBox "Pas d'erreurs" "Sympa! Apparemment il n'y a pas d'erreurs!"
    fi
}

function compress() {
    yesOrNot "Compression" "Démarrage de la compression dans 1s après validation de cette fenêtre!"
    sleep 1
    dateAndTime=`date +%d-%m-%Y_%H:%M`
    tailboxRsync "compress.log" &
    c=`tar -czvf $2/backup_$dateAndTime.tar.gz $1 1> compress.log 2> compress_errors.log`
    msgBox "Compression Terminée" "La compression est finie!!\nLe nom du fichier s'appelle backup_$dateAndTime.tar.gz"
    checkErrors "compress_errors.log"
    end
}

function tailboxRsync() {
    sleep 1
    $DIALOG --begin 15 10 --tailbox $1  20 125
}

function sync() {
    yesOrNot "Synchronisation" "Démarrage de la synchronisation dans 1s après validation de cette fenêtre!"
    sleep 1
    tailboxRsync "rsync.log" &
    c=`rsync -arlpvtgoDu --progress $1 $2 1> rsync.log 2> rsync_errors.log`
    msgBox "Synchronisation Terminée" "La synchronisation est finie!!\n"
    checkErrors "rsync_errors.log"
    end
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
