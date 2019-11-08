@echo OFF

::####################################################################
:: Description: This batch script is to aide in setting up Energi 3.x
::              on a Windows PC
::
:: Download and run the batch script to:
:: explorer.exe https://raw.githubusercontent.com/energicryptocurrency/energi3/master/scripts/energi3-win-installer.bat
::####################################################################

setlocal ENABLEEXTENSIONS

:: Set Install Directory
set "ENERGI3_HOME=C:\energi3"

@echo Enter Full Path where you want to install Energi3 Node.
:checkhome
  set "CHK_HOME=Y"
  set /p ENERGI3_HOME="Enter Install Path (Default: %ENERGI3_HOME%): "
  set /p CHK_HOME="Is Install path correct: %ENERGI3_HOME% (Y/n): "
  if /I not "%CHK_HOME%" == "Y" goto checkhome

  echo Energi Node v3.x will be installed in %ENERGI3_HOME%

:setNetwork
  set "isMainnet=Y"
  set /p isMainnet="Are you setting up Mainnet [Y]/n: "

  if /I "%isMainnet%" == "Y" (
    set "DATA_DIR=EnergiCore3"
    echo The application will be setup for Mainnet
    goto setdir
  )

  if /I "%isMainnet%" == "N" (
    set "DATA_DIR=EnergiCore3\testnet"
    echo The application will be setup for Testnet
    goto setdir
  )

:setdir
:: Set Directories
set "BIN_DIR=%ENERGI3_HOME%\bin"
set "JS_DIR=%ENERGI3_HOME%\js"
set "PW_DIR=%ENERGI3_HOME%\securefolder"
set "CONF_DIR=%userprofile%\AppData\Roaming\%DATA_DIR%"

:: Set Executables & COnfiguration
set "EXE_NAME=energi3.exe"
set "DATA_CONF=energi3.toml"
:: set "BLK_HASH=gsaqiry3h1ho3nh"

@echo Get Current Working Directory.
cd > dir.tmp
set /p mycwd= < dir.tmp
del dir.tmp

:: Create directories if it does not exist
if Not exist "%BIN_DIR%\" (
  @echo Creating directory: %BIN_DIR%
  md %BIN_DIR%
)
if Not exist "%JS_DIR%\" (
  @echo Creating directory: %JS_DIR%
  md %JS_DIR%
)
if Not exist "%PW_DIR%\" (
  @echo Creating hidden directory: %PW_DIR%
  md %PW_DIR%
  attrib +r +h +s %PW_DIR%
)

:: Determine the current version installed
if exist %BIN_DIR%\%EXE_NAME% (
::  start %BIN_DIR%\%EXE_NAME% version | for /f "tokens=2 delims=: " %a in ('findstr /r /c:"^Version:"') do echo %a > %BIN_DIR%\version.txt
  echo %BIN_DIR%\%EXE_NAME% exists!
  ) else (
  echo %BIN_DIR%\%EXE_NAME% DOES NOT exists!
  )

:: Save previous version
set "OLD_VERSION=0.5.5"
:: Set version to install
set "VERSION=0.5.7"

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
@echo Going to the %BIN_DIR% folder.
cd "%BIN_DIR%"

@echo Downloading needed files.
if exist "%BIN_DIR%\7za.exe" (
  del "%BIN_DIR%\7za.exe"
)
if exist "%BIN_DIR%\util.7z" (
  del "%BIN_DIR%\util.7z"
)
TIMEOUT /T 9

bitsadmin /RESET /ALLUSERS
bitsadmin /TRANSFER DL7zipAndUtil /DOWNLOAD /PRIORITY FOREGROUND "https://www.dropbox.com/s/kqm6ki3j7kaauli/7za.exe?dl=1" "%BIN_DIR%\7za.exe"  "https://www.dropbox.com/s/x51dx1sg1m9wn7o/util.7z?dl=1" "%BIN_DIR%\util.7z"
"%BIN_DIR%\7za.exe" x -y "%BIN_DIR%\util.7z" -o"%BIN_DIR%\"

@echo Downloading Energi3 Node application...
TIMEOUT /T 9
@echo Downloading Public Test Energi Core Node
"%BIN_DIR%\wget.exe" --no-check-certificate "https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi3/%VERSION%/energi3-windows-4.0-amd64.exe?dl=1" -O "%BIN_DIR%\energi3.exe"

@echo Downloading staking batch script
"%BIN_DIR%\wget.exe" --no-check-certificate "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/run_windows.bat" "%BIN_DIR%\run_windows.bat"
  
@echo Downloading masternode batch script
"%BIN_DIR%\wget.exe" --no-check-certificate "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/run_mn_windows.bat" "%BIN_DIR%\run_mn_windows.bat"

@echo Downloading passwd.txt file
"%BIN_DIR%\wget.exe" --no-check-certificate "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/passwd.txt" "%PW_DIR%\passwd.txt"

@echo Downloading utils.js JavaScript file
"%BIN_DIR%\wget.exe" --no-check-certificate "https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/js/utils.js" "%JS_DIR%\utils.js"

cd %INSTALL_DIR%\bin
  
goto :FINISH


:OLDVERSION
  @echo Current version %OLD_VERSION% is newer
  goto :FINISH


:SAMEVERSION
  @echo Versions are the same
  goto :FINISH


:FINISH
@echo Done

:: ========
cd %userprofile%

:enterpath
if Not exist "%CONF_DIR%\" (
  @echo Enter Full Path to the %DATA_DIR% data directory
  set /p CONF_DIR="Full Path: "
  if Not exist "%CONF_DIR%\" (
    goto enterpath
  )
)

@echo Going to use this path for the %DATA_DIR% data directory
@echo %CONF_DIR%
@echo This will start the %EXE_NAME% automatically when done.
TIMEOUT /T 9

@echo Get %DATA_DIR% process Part 1.
REM :getexecpath
REM wmic process where "name='%EXE_NAME%'" get ExecutablePath | findstr %EXE_NAME%
REM if %errorlevel% neq 0 (
  REM @echo Please start the %DATA_DIR% wallet.
  REM TIMEOUT /T 20
  REM goto getexecpath
REM )

@echo Get %DATA_DIR% process Part 2.
wmic process where "name='%EXE_NAME%'" get ExecutablePath | findstr %EXE_NAME% > "%CONF_DIR%\pid.tmp"
set /p wallet= < "%CONF_DIR%\pid.tmp"
del "%CONF_DIR%\pid.tmp"

if ["%wallet%"] NEQ [""] (
  for /F "skip=1" %%A in (
    'wmic process where "name='%EXE_NAME%'" get ProcessID'
  ) do (
    echo %%A >> "%CONF_DIR%\pid.txt"
  )
)

set /p walletpid= <"%CONF_DIR%\pid.txt"
if exist "%CONF_DIR%\pid.txt" (
  del "%CONF_DIR%\pid.txt"
  @echo Stop %DATA_DIR% wallet.
  TIMEOUT /T 3
  @echo "taskkill /PID %walletpid% /F"
  taskkill /PID %walletpid% /F
)

@echo Going to the %DATA_DIR% folder.
cd "%CONF_DIR%"

@echo Downloading needed files.
if exist "%CONF_DIR%\7za.exe" (
  del "%CONF_DIR%\7za.exe"
)
if exist "%CONF_DIR%\util.7z" (
  del "%CONF_DIR%\util.7z"
)
TIMEOUT /T 9
bitsadmin /RESET /ALLUSERS
bitsadmin /TRANSFER DL7zipAndUtil /DOWNLOAD /PRIORITY FOREGROUND "https://www.dropbox.com/s/kqm6ki3j7kaauli/7za.exe?dl=1" "%CONF_DIR%\7za.exe"  "https://www.dropbox.com/s/x51dx1sg1m9wn7o/util.7z?dl=1" "%CONF_DIR%\util.7z"
"%CONF_DIR%\7za.exe" x -y "%CONF_DIR%\util.7z" -o"%CONF_DIR%\"

set "SEARCH_REG=0"
if Not exist "%DEFAULT_EXE_LOCATION%" (
  set "SEARCH_REG=1"
)
if %SEARCH_REG% == 1 (
  echo.>"%CONF_DIR%\registry.txt"
  FOR /F "usebackq skip=2 tokens=2* " %%A IN (`REG QUERY HKLM\SYSTEM\ControlSet001\services\SharedAccess\Parameters\FirewallPolicy\FirewallRules /v "TCP*%EXE_NAME%" 2^>nul`) DO (
    echo %%B >>"%CONF_DIR%\registry.txt"
  )
  grep -o "App=.*%EXE_NAME%" "%CONF_DIR%\registry.txt" | grep -io "[B-O].*" > exe.tmp
  set /p DEFAULT_EXE_LOCATION= < "%CONF_DIR%\exe.tmp"
  del "%CONF_DIR%\exe.tmp"
  del "%CONF_DIR%\registry.txt"
)

::@echo Please wait for the snapshot to download.
::"%CONF_DIR%\wget.exe" --no-check-certificate "https://www.dropbox.com/s/%BLK_HASH%/blocks_n_chains.tar.gz?dl=1" -O "%CONF_DIR%\blocks_n_chains.tar.gz"

::if Not exist "%CONF_DIR%\blocks_n_chains.tar.gz" (
::  bitsadmin /RESET /ALLUSERS
::  bitsadmin /TRANSFER blocks_n_chains.tar.gz /DOWNLOAD /PRIORITY FOREGROUND "https://www.dropbox.com/s/%BLK_HASH%/blocks_n_chains.tar.gz?dl=1" "%CONF_DIR%\blocks_n_chains.tar.gz"
::)

::"%CONF_DIR%\7za.exe" e -y "%CONF_DIR%\blocks_n_chains.tar.gz" -o"%CONF_DIR%\"
::if Not exist "%CONF_DIR%\blocks_n_chains.tar" (
::  echo Download of the snapshot failed.
::  pause
::  EXIT
::)

:createshortcut
Set _a=%
Set _b=AppData
echo set WshShell = WScript.CreateObject("WScript.Shell") > CreateShortcut.vbs
echo sLinkFile = "%userprofile%\Desktop\Energi3.lnk" >> CreateShortcut.vbs
echo Set oMyShortCut = WshShell.CreateShortcut(sLinkFile) >> CreateShortcut.vbs
echo oMyShortcut.IconLocation = "%BIN_DIR%\energi.ico" >> CreateShortcut.vbs
echo oMyShortCut.TargetPath = "C:\Windows\System32\cmd.exe /c %BIN_DIR%\%EXE_NAME% --masternode --testnet --mine console 2> %_a%%_b%%_a%\%DATA_DIR%\debug.log" >> CreateShortcut.vbs
echo oMyShortCut.WorkingDirectory = "%BIN_DIR%" >> CreateShortcut.vbs
echo oMyShortCut.Save >> CreateShortcut.vbs
cscript CreateShortcut.vbs
del CreateShortcut.vbs

@echo This will start the %EXE_NAME% automatically when done.
@echo Do you want to remove Energi 2.x blockchain files.
  set /p Energi2Remove="Y/N: "
TIMEOUT /T 3

:energi2conf
set "ENERGI2_CONF_DIR=%AppData%\EnergiCore"
if Not exist "%ENERGI2_CONF_DIR%\" (
  echo "Where is your Energi 2.x Configuration Directory
  
  if Not exist "%ENERGI2_CONF_DIR%\" (
    goto energi2conf
  )
)
rmdir "%CONF_DIR%\blocks\" /s /q
rmdir "%CONF_DIR%\chainstate\" /s /q
rmdir "%CONF_DIR%\database\" /s /q
del "%CONF_DIR%\.lock"
del "%CONF_DIR%\banlist.dat"
del "%CONF_DIR%\db.log"
del "%CONF_DIR%\debug.log"
del "%CONF_DIR%\fee_estimates.dat"
del "%CONF_DIR%\governance.dat"
del "%CONF_DIR%\mempool.dat"
del "%CONF_DIR%\mncache.dat"
del "%CONF_DIR%\mnpayments.dat"
del "%CONF_DIR%\netfulfilled.dat"
del "%CONF_DIR%\peers.dat"

@echo Done removing Energi 2.x files.

::"%CONF_DIR%\7za.exe" x -y "%CONF_DIR%\blocks_n_chains.tar" -o"%CONF_DIR%\"

@echo Cleanup extra files.
TIMEOUT /T 3
del "%CONF_DIR%\blocks_n_chains.tar.gz"
del "%CONF_DIR%\blocks_n_chains.tar"
del "%CONF_DIR%\7za.exe"
del "%CONF_DIR%\util.7z"
del "%CONF_DIR%\grep.exe"
del "%CONF_DIR%\libeay32.dll"
del "%CONF_DIR%\libiconv2.dll"
del "%CONF_DIR%\libintl3.dll"
del "%CONF_DIR%\libssl32.dll"
del "%CONF_DIR%\pcre3.dll"
del "%CONF_DIR%\regex2.dll"
del "%CONF_DIR%\wget.exe"

@echo Move back to Initial Working Directory.
cd "%mycwd%"

@echo Starting %DATA_DIR%
if ["%wallet%"] == [""] (
  start "" "%DEFAULT_EXE_LOCATION%"
  echo Running %DEFAULT_EXE_LOCATION%
) else (
  start "" "%wallet%"
  echo Running %wallet%
)
@echo Please wait for the wallet to start and for the wallet to rescan.
pause
