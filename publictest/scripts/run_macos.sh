#!/bin/bash
#####################################################################
# Description: This script is to start energicore3 public test node
#              server
#
# Download this script
# wget https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_macos.sh
#####################################################################
#

export PATH=$PATH:$HOME/Downloads

# Create directory for logfile
if [ ! -d "${HOME}/Library/Application Support/EnergiCore3/testnet/log" ]
then
        mkdir -p "${HOME}/Library/Application Support/EnergiCore3/testnet/log"
fi

# Install dig which is part of bind
brew install bind

# Make executable
if [ ! -x $HOME/Downloads/energi3-darwin-10.6-amd64 ]
then
    chmod +x $HOME/Downloads/energi3-darwin-10.6-amd64
fi

# Set variables
LOGFILE="${HOME}/Library/Application Support/EnergiCore3/testnet/log/energicore3.log"
IP=`dig +short myip.opendns.com @resolver1.opendns.com`

if [ "x$IP" != "x" ]
then
   $HOME/Downloads/energi3-darwin-10.6-amd64 \
        --masternode \
        --nat extip:${IP} \
        --testnet \
        --mine \
        --rpcapi admin,eth,web3,rpc,personal \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --verbosity 3 \
        console 2>> $LOGFILE
else
    echo "Cannot determine external IP address"
    echo "Run manually: $HOME/Downloads/energi3-darwin-10.6-amd64 --testnet console 2>> \"$LOGFILE\" "
fi
