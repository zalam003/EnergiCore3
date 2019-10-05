@echo OFF

::####################################################################
:: Description: This script is to start Energi 3.x aka Gen3 in
::              Windows environment
::
:: Run this script
:: run_windows.bat
::####################################################################

set "VERSION=0.5.5"

set "INSTALL_DIR=C:\Apps\EnergiCore3"
set "DATA_DIR=EnergiCore3\testnet\energi3"
set "BLOCKCHAIN_DIR=%userprofile%\AppData\Roaming\%DATA_DIR%"
set "DEFAULT_EXE_LOCATION=%INSTALL_DIR%\energi3-windows-4.0-amd64.exe"

@echo Changing to install directory
cd "%INSTALL_DIR%"

@echo Starting Energi Core Node %VERSION%
%windir%\system32\cmd.exe /c %DEFAULT_EXE_LOCATION% --testnet console 2> %DATA_DIR%\enegi3debug.log
