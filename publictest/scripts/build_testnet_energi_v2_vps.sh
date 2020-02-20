#!/bin/bash

# Run:
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/build_testnet_energi_v2_vps.sh)" ; source ~/.bashrc
```
'
#

TESTNETCONFDIR=${HOME}/.energicore/testnet1

sudo apt-get install software-properties-common -yq

echo | sudo add-apt-repository ppa:bitcoin/bitcoin

sudo apt-get update

sudo apt install libboost-dev libboost-system-dev libboost-filesystem-dev libboost-program-options-dev libboost-thread-dev libevent-pthreads-2.1-6 libminiupnpc10 libzmq5 libdb4.8 libdb4.8++ unzip -y

sudo apt-get install -y virtualenv python-virtualenv

wget https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi/v2.3.0.3/energicore-2.3.0.3-linux.tar.gz
tar -xvzf energicore-2.3.0.3-linux.tar.gz
mv energicore-2.3.0 energi

cd .energicore/testnet1
unzip https://github.com/zalam003/EnergiCore3/releases/download/v2.2.1-testnet/testnet-bootstrap-20200209.zip

EXTERNALIP=$( timeout --signal=SIGKILL 10s curl -s http://ipinfo.io/ip )
HOSTIP=$( ip addr show | grep inet | grep -v "inet6" | grep -v 127.0.0.1 | grep -v "docker" | sed 's/\// /g' | awk '{ print $2 }' )

if [ ! -d ${TESTNETCONFDIR} ]
then
        mkdir -p ${TESTNETCONFDIR}
else
        echo "$HOME/.energicore already exists..."
fi

if [ ! -f ${TESTNETCONFDIR}/energi.conf ]
then
  cat << NRGCONF | ${TESTNETCONFDIR}/energi.conf >/dev/null
rpcuser=nrg_mig
rpcpassword=fasdlfkjadfpndlvnpihhsodfhadfaaf
rpcallowip=127.0.0.1
rpcport=19796
rpcbind=127.0.0.1
bind=${HOSTIP}:19797
listen=1
server=1
daemon=1
staking=1
printtodebug=0
printtoconsole=0
maxconnections=24
externalip=${EXTERNALIP}:19797
#masternode=1
#masternodeprivkey=PRIVKEY
NRGCONF

else
        echo "${TESTNETCONFDIR}/energi.conf exists..."
        echo "Update any parameters necessary"
fi

echo "export PATH=${PATH}:${HOME}/energi/bin" >> ~/.bashrc

source ~/.bashrc

energid --testnet -daemon

cd ${TESTNETCONFDIR}
git clone https://github.com/energicryptocurrency/sentinel.git
cd sentinel
sed -i "s/\#energi_conf\=\/home\/dev\/.energicore/$TESTNETCONFDIR/g" sentinel.conf
virtualenv venv
venv/bin/pip install -r requirements.txt
venv/bin/python bin/sentinel.py