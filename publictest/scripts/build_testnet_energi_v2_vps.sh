#!/bin/bash

if [ ! -d $HOME/.energicore/testnet1 ]
then
        mkdir -p $HOME/.energicore/testnet1
else
        echo "$HOME/.energicore/testnet1 already exists..."
fi

if [ ! -f $HOME/.energicore/testnet1/energi.conf ]
then
  echo "Setting up energi.conf"

cat << ENERGI_CONF | tee $HOME/.energicore/testnet1/energi.conf >/dev/null
        rpcuser=nrg_rpc
rpcpassword=qjsDgPgb5QHSkuBvDih2PQc6Q1qE4Amsdv2aoHbjMFrC
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=55711
server=1
daemon=1
logtimestamps=1
listen=1
staking=1
masternode=0
#externalip=123.123.123.123:9797
#bind=10.1.1.10:9797
maxconnections=24
ENERGI_CONF

        
else
        echo "$HOME/.energicore/testnet1/energi.conf exists..."
        echo
fi

sudo apt-get install software-properties-common -y

sudo add-apt-repository ppa:bitcoin/bitcoin

sudo apt-get update

sudo apt install libboost-dev libboost-system-dev libboost-filesystem-dev libboost-program-options-dev libboost-thread-dev libevent-pthreads-2.1-6 libminiupnpc10 libzmq5 libdb4.8 libdb4.8++ unzip -y

wget https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi/v2.2.1/energicore-2.2.1-linux.tar.gz
tar -xvzf energicore-2.2.1-linux.tar.gz
mv energicore-2.2.1 energi
ls -l
echo "export PATH=${PATH}:${HOME}/energi/bin" >> ~/.bashrc

cd .energicore/testnet1
unzip https://github.com/zalam003/EnergiCore3/releases/download/v2.2.1-testnet/testnet-bootstrap-20200209.zip

source ~/.bashrc

energid --testnet -daemon

