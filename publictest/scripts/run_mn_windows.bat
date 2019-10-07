@echo OFF

::####################################################################
:: Description: This script is to start Energi 3.x aka Gen3 in
::              Windows environment
:: Replace:     "unlock" address
::              create a file named passwd.txt with password of address
:: Run script:  run_mn_windows.bat
::####################################################################

set "VERSION=0.5.5"

:: energi3-windows-4.0-amd64.exe version >version.tmp
:: findstr /B Version version.tmp
:: del version.tmp

set "INSTALL_DIR=C:\EnergiCore3"
set "DATA_DIR=EnergiCore3\testnet\energi3"
set "BLOCKCHAIN_DIR=%userprofile%\AppData\Roaming\%DATA_DIR%"
set "DEFAULT_EXE_LOCATION=%INSTALL_DIR%\energi3-windows-4.0-amd64.exe"

@echo Changing to install directory
cd "%INSTALL_DIR%"

@echo Starting Energi Core Node %VERSION%
%windir%\system32\cmd.exe /c %DEFAULT_EXE_LOCATION%^
    --masternode^
    --testnet^
    --mine^
    --unlock 0x16c5074d9fc6afdbc021a8e44c8511d1a090f9ad^
    --password passwd.txt^
    --rpcapi admin,eth,web3,rpc,personal^
    --rpc^
    --rpcport 49796^
    --rpcaddr "127.0.0.1"^
   	--verbosity 3 console 2>> %BLOCKCHAIN_DIR%\enegi3debug.log
