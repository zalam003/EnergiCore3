#!/bin/bash
#####################################################################
# Description: This script is to start energicore3 public test node
#              staking server
#
# Download this script
# wget https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_linux.sh
#####################################################################
#

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$HOME/energi3/bin

# Create directory for logfile
if [ ! -d $HOME/.energicore3/testnet/log ]
then
        mkdir -p $HOME/.energicore3/testnet/log
fi

# Make executable
if [ ! -x $HOME/energi3/bin/energi3 ]
then
    chmod +x $$HOME/energi3/bin/energi3
fi

# Set variables
LOGFILE=$HOME/.energicore3/testnet/log/energicore3.log
JSHOME="$HOME/energi3/js"

if [ -f ${HOME}/.energicore3/testnet/keystore/UTC* ]
then
    energi3 \
        --testnet \
        --preload ${JSHOME}/utils.js \
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
        console 2>> ${LOGFILE}
else
    energi3 \
        --testnet \
        --preload ${JSHOME}/utils.js \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --rpcapi admin,eth,web3,rpc,personal,energi \
        --ws \
        --wsaddr "127.0.0.1" \
        --wsport 49795 \
        --wsapi admin,eth,net,web3,personal,energi \
        --verbosity 3 \
        console 2>> ${LOGFILE}
fi
