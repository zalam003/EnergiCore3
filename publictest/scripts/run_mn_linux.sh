#!/bin/bash
#####################################################################
# Description: This script is to start energicore3 public test node
#              masternode server
#
# Download this script
# wget https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_mn_linux.sh
#####################################################################
#

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$HOME/energi3/bin


if [ ! -d $HOME/.energicore3/testnet/log ]
then
        mkdir -p $HOME/.energicore3/testnet/log
fi

# Set variables
LOGFILE=$HOME/.energicore3/testnet/log/energicore3.log
JSHOME=$HOME/energi3/js
IP=`dig +short myip.opendns.com @resolver1.opendns.com`

if [ "x$IP" != "x" ]
then
    energi3 \
        --masternode \
        --nat extip:${IP} \
        --testnet \
        --preload $JSHOME/utils.js \
        --mine \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --rpcapi admin,eth,web3,rpc,personal,energi \
        --ws \
        --wsaddr "127.0.0.1" \
        --wsport 49795 \
        --wsapi admin,eth,net,web3,personal,energi \
        --verbosity 3 \
        console 2>> $LOGFILE
else
    echo "Lookup external IP address by going to http://ip.me"
    energi3 \
        --masternode \
        --testnet \
        --mine \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --rpcapi admin,eth,web3,rpc,personal,energi \
        --ws \
        --wsaddr "127.0.0.1" \
        --wsport 49795 \
        --wsapi admin,eth,net,web3,personal,energi \
        --verbosity 3 \
        console 2>> $LOGFILE
fi
