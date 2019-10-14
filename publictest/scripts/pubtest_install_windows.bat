@echo OFF

::####################################################################
:: Description: This script is to aide in setting up Energi 3.x aka
::              Gen3 in a Unix environment
::
:: Run this script
:: bitsadmin /transfer DLInstStartScript /download /priority foreground "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/pubtest_install_windows.bat" "%cd%\pubtest_install_windows.bat"
::####################################################################

setlocal ENABLEEXTENSIONS

REM ###===> Update if needed
REM # Save previous version
set "OLD_VERSION=0.5.5"
REM # Set version to install
set "VERSION=0.5.7"

set "INSTALL_DIR=C:\Apps\EnergiCore3"
set "DATA_DIR=EnergiCore3\testnet\energi3"
set "BLOCKCHAIN_DIR=%userprofile%\AppData\Roaming\%DATA_DIR%"
set "DEFAULT_EXE_LOCATION=%INSTALL_DIR%\energi3-windows-4.0-amd64.exe"

:: Compare Versions
call :testVersions  %VERSION%      %OLD_VERSION%
exit /b

:testVersions  version1  version2
call :compareVersions %1 %2
if %errorlevel% == 1 goto :NEWVERSION
if %errorlevel% == -1 goto :OLDVERSION
if %errorlevel% == 0 goto :SAMEVERSION
echo %~1 is %result% %~2
exit /b

:compareVersions  version1  version2
rem
rem  Compares two version numbers and returns the result in the ERRORLEVEL
rem 
rem Returns 1 if version1 > version2
rem         0 if version1 = version2
rem        -1 if version1 < version2
rem
rem The nodes must be delimited by . or , or -
rem
rem Nodes are normally strictly numeric, without a 0 prefix. A letter suffix
rem is treated as a separate node
rem
setlocal enableDelayedExpansion
set "v1=%~1"
set "v2=%~2"
call :divideLetters v1
call :divideLetters v2
:loop
call :parseNode "%v1%" n1 v1
call :parseNode "%v2%" n2 v2
if %n1% gtr %n2% exit /b 1
if %n1% lss %n2% exit /b -1
if not defined v1 if not defined v2 exit /b 0
if not defined v1 exit /b -1
if not defined v2 exit /b 1
goto :loop

:parseNode  version  nodeVar  remainderVar
for /f "tokens=1* delims=.,-" %%A in ("%~1") do (
  set "%~2=%%A"
  set "%~3=%%B"
)
exit /b

:divideLetters  versionVar
for %%C in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do set "%~1=!%~1:%%C=.%%C!"
exit /b

:NEWVERSION
  echo Installing new version %VERSION%
  if Not exist "%INSTALL_DIR%\" (
  @echo "Creating %INSTALL_DIR%"
  md %INSTALL_DIR%
  )
  cd %INSTALL_DIR%
  @echo Downloading application...
  TIMEOUT /T 9
  
  bitsadmin /RESET /ALLUSERS
  @echo Downloading Public Test Energi Core Node
  bitsadmin /transfer DLPubTestNode /download /priority foreground "https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi3/%VERSION%/energi3-windows-4.0-amd64.exe" "%INSTALL_DIR%\energi3-windows-4.0-amd64.exe"
  
  @echo Downloading staking batch script
  bitsadmin /transfer DLInstStartScript /download /priority foreground "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/run_windows.bat" "%INSTALL_DIR%\run_windows.bat"
  
  @echo Downloading masternode batch script
  bitsadmin /transfer DLInstStartScript /download /priority foreground "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/run_mn_windows.bat" "%INSTALL_DIR%\run_mn_windows.bat"
  
  @echo Downloading passwd.txt file
  bitsadmin /transfer DLInstStartScript /download /priority foreground "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/passwd.txt" "%INSTALL_DIR%\passwd.txt"
  
  goto :FINISH


:OLDVERSION
  @echo Current version %OLD_VERSION% is newer
  goto :FINISH


:SAMEVERSION
  @echo Versions are the same
  goto :FINISH


:FINISH
@echo Done
pause
