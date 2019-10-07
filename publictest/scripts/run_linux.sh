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
if [ ! -x $HOME/energi3/bin/energi3-linux-amd64 ]
then
    chmod +x $$HOME/energi3/bin/energi3-linux-amd64
fi

# Set variables
LOGFILE=$HOME/.energicore3/testnet/log/energicore3.log

energi3-linux-amd64 \
        --nat extip:${IP} \
        --testnet \
        --mine \
        --rpcapi admin,eth,web3,rpc,personal \
        --rpc \
        --rpcport 49796 \
        --rpcaddr "127.0.0.1" \
        --verbosity 3 \
        console 2>> $LOGFILE

