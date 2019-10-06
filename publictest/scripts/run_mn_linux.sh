#!/bin/bash

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
    energi3-linux-amd64 \
        --masternode \
        --nat extip:${IP} \
        --testnet \
        --preload $JSHOME/utils.js \
        --mine \
        --rpcapi admin,eth,web3,rpc,personal \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --verbosity 3 \
        console 2>> $LOGFILE
else
    echo "Cannot determine external IP address"
    energi3-linux-amd64 \
        --masternode \
        --testnet \
        --mine \
        --rpcapi admin,eth,web3,rpc,personal \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --verbosity 3 \
        console 2>> $LOGFILE
fi
