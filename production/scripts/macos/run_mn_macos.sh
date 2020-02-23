#!/usr/bin/env bash
#####################################################################
# Description: This script is to start energicore3 public test node
#              masternode server
#
# Download this script
# curl -sL https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_mn_macos.sh > run_mn_macos.sh
#####################################################################
#

export PATH=$PATH:$HOME/energi3/bin

# Create directory for logfile
if [ ! -d "${HOME}/Library/EnergiCore3/testnet/log" ]
then
        mkdir -p "${HOME}/Library/EnergiCore3/testnet/log"
fi

# Install dig which is part of bind
#brew install bind

# Make executable
if [ ! -x $HOME/Downloads/energi3 ]
then
    chmod +x $HOME/Downloads/energi3
fi

# Set variables
LOGFILE="${HOME}/Library/EnergiCore3/testnet/log/energicore3.log"
JSHOME="${HOME}/energi3/js"
#IP=`dig +short myip.opendns.com @resolver1.opendns.com`

if [ -f ${HOME}/Library/EnergiCore3/testnet/keystore/UTC* ]
then
   $HOME/energi3/bin/energi3 \
        --masternode \
        --testnet \
        --preload $JSHOME/utils.js \
        --mine \
        --rpcapi admin,eth,web3,rpc,personal \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --verbosity 3 \
        console 2>> ${LOGFILE}
else
    $HOME/energi3/bin/energi3 \
        --masternode \
        --testnet \
        --preload $JSHOME/utils.js \
        --rpcapi admin,eth,web3,rpc,personal \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --verbosity 3 \
        console 2>> ${LOGFILE}
fi
