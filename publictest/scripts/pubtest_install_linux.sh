#!/bin/bash
#####################################################################
# Description: This script is to aide in setting up Energi 3.x aka
#              Gen3 in a Unix environment
#
# Run this script
# bash -i <( curl -sL https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/pubtest_install_linux.sh )
#####################################################################
#

# Uncomment for debugging
#set -x

# Set version to install
VERSION=0.5.4

# Check OS
if [ `uname` == "Linux" ]
then
        OSVER=linux
else
        echo "Cannot use this script"
        exit 0
fi

# Function to compare versions
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Create if directory does not exists
if [ ! -d $HOME/energi3/bin ]
then
        mkdir -p $HOME/energi3/bin
fi

#
if [ ! -d $HOME/.energicore3/testnet/log ]
then
        mkdir -p $HOME/.energicore3/testnet/log
fi

# Get current version installed
INSTVER=`cat version.txt`
#echo "INSTVER: " ${INSTVER}

# Compare and run install if needed
vercomp $INSTVER $VERSION
case $? in
    0)
        echo "Version are the same"
        #echo "$INSTVER = $VERSION"
        echo "Nothing to install"
        ;;

    1)
        echo "Current Installation is newer: " ${INSTVER}
        #echo "$INSTVER > $VERSION"
        echo "Nothing to install"
        ;;

    2)
        echo "Installing newer version"
        #echo "$INSTVER < $VERSION"
        
        # Change to install directory
        cd $HOME/energi3/bin

        echo "Downloading ${VERSION} for ${OSVER}"
        wget https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi3/${VERSION}/energi3-${OSVER}-amd64
        chmod +x energi3-${OSVER}-amd64

        echo "Downloading script to start Energi Core Node server"
        wget https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_linux.sh
        chmod +x run_linux.sh
        
        # Update version file
        echo $VERSION > version.txt
        ;;

esac


