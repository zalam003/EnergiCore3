#!/bin/bash

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:$HOME/energi3/bin

# Start masternode in screen
screen -S energi3 run_mn_linux.sh
