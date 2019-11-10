@echo OFF

::####################################################################
:: Description: This script is to start Energi 3.x aka Gen3 in
::              Windows environment
:: Replace:     "unlock" address
::              create a file named passwd.txt with password of address
:: Run script:  run_mn_windows.bat
::####################################################################

set "VERSION=0.5.7"

:: energi3.exe version >version.tmp
:: findstr /B Version version.tmp
:: del version.tmp

set "BIN_DIR=C:\energi3\bin"
set "DATA_DIR=EnergiCore3\testnet\energi3"
set "LOG_DIR=%APPDATA%\EnergiCore3\testnet\log"
set "BLOCKCHAIN_DIR=%APPDIR%\%DATA_DIR%"
set "DEFAULT_EXE_LOCATION=%BIN_DIR%\energi3.exe"
set "JSHOME=%BIN_DIR%\js"
set "PERSONAL_ACCOUNT="

@echo Changing to install directory
cd "%BIN_DIR%"

@echo Starting Energi Core Node %VERSION%
@echo Update your account information in the unlock parameter.
@echo Update/create a file called passwd.txt. Include your passphrase in the file
%windir%\system32\cmd.exe /c %DEFAULT_EXE_LOCATION%^
    --masternode^
    --testnet^
    --mine^
    --unlock %PERSONAL_ACCOUNT%^
    --password passwd.txt^
    --preload %JSHOME%\utils.js^
    --rpc^
    --rpcport 49796^
    --rpcaddr "127.0.0.1"^
    --rpcapi admin,eth,web3,rpc,personal,energi^
    --ws^
    --wsaddr "127.0.0.1"^
    --wsport 49795^
    --wsapi admin,eth,net,web3,personal,energi^
    --verbosity 3 console 2>> %LOG_DIR%\enegi3debug.log
