#!/bin/bash
#####################################################################
# Description: This script is to aide in setting up Energi 3.x aka
#              Gen3 in a Unix environment
#
# Run this script
# bash -i <( curl -sL https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/pubtest_install_macos.sh )
#####################################################################
#

# Uncomment for debugging
#set -x

###===> Update if needed
# Set Previos version to save a copy
OLD_VERSION=0.7.1
# Set version to install
VERSION=0.8.2

# Check OS
if [ `uname` == "Darwin" ]
then
        OSVER=darwin
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
if [ ! -d "${HOME}/energi3/bin" ]
then
        mkdir -p "${HOME}/energi3/bin"
fi

# Create if directory does not exists
if [ ! -d "${HOME}/Library/EnergiCore3/testnet/log" ]
then
        mkdir -p "${HOME}/Library/EnergiCore3/testnet/log"
fi

# Get current version installed
if [ -f $HOME/energi3/bin/version.txt ]
then
    INSTVER=`cat $HOME/energi3/bin/version.txt`
else
    INSTVER=0.0.1
fi
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

        echo "Downloading ${VERSION} for ${OSVER} in `pwd`"        
        mv energi3-${OSVER}-10.6-amd64 energi3-${OSVER}-10.6-amd64-${OLD_VERSION}
        curl https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi3/${VERSION}/energi3-${OSVER}-10.6-amd64 --output energi3-${OSVER}-10.6-amd64
        chmod +x energi3-${OSVER}-10.6-amd64
        mv energi3-${OSVER}-10.6-amd64 energi3
        
        echo "Downloading staking script to start Energi Core Node server: run_macos.sh"
        curl -sL https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_macos.sh > run_macos.sh
        chmod +x run_macos.sh
        
        echo "Downloading masternode script to start Energi Core Node server: run_macos.sh"
        curl -sL https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_mn_macos.sh > run_mn_macos.sh
        chmod +x run_mn_macos.sh
        
        echo "Download javascript"
        if [ ! -d "${HOME}/energi3/js" ]
        then
                mkdir -p "${HOME}/energi3/js"
        fi
        cd ${HOME}/energi3/js
        curl -sL https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/js/utils.js > utils.js
        chmod 644 utils.js
        
        cd $HOME/energi3/bin

        # Update version file
        echo $VERSION > version.txt
        ;;

esac

