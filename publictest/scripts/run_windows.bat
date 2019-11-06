@echo OFF

::####################################################################
:: Description: This script is to start Energi 3.x aka Gen3 in
::              Windows environment
::
:: Run this script
:: run_windows.bat
::####################################################################

set "VERSION=0.5.5"

set "BIN_DIR=C:\energi3\bin"
set "DATA_DIR=EnergiCore3\testnet\energi3"
set "LOG_DIR=%APPDATA%\EnergiCore3\log"
set "BLOCKCHAIN_DIR=%APPDATA%\%DATA_DIR%"
set "DEFAULT_EXE_LOCATION=%BIN_DIR%\energi3.exe"
set "JSHOME=%BIN_DIR%\js"

@echo Changing to install directory
cd "%BIN_DIR%"

@echo Starting Energi Core Node %VERSION%
%windir%\system32\cmd.exe /c %DEFAULT_EXE_LOCATION% --testnet console 2> %BLOCKCHAIN_DIR%\enegi3debug.log
pause
