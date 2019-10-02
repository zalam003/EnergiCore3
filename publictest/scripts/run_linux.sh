#!/bin/bash
#####################################################################
# Description: This script is to aide in setting up Energi 3.x aka
#              Gen3 in a Unix environment
#
# Download this script
# wget https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/pubtest_install_macos.sh )
#####################################################################
#

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$HOME/energi3/bin

# Create directory for logfile
if [ ! -d $HOME/.energicore3/testnet/log ]
then
        mkdir -p $HOME/.energicore3/testnet/log
fi

# Set variables
LOGFILE=$HOME/.energicore3/testnet/log/energicore3.log
IP=`dig +short myip.opendns.com @resolver1.opendns.com`

if [ "x$IP" != "x" ]
then
   energi3-linux-amd64 \
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
fi
