@echo OFF

::####################################################################
:: Description: This batch script is to aide in setting up Energi 3.x
::              on a Windows PC. It can be used to upgrade existing
::              installations
::
:: Download and run the batch script to:
:: explorer.exe https://raw.githubusercontent.com/energicryptocurrency/energi3/master/scripts/energi3-installer.bat
::####################################################################

setlocal ENABLEEXTENSIONS

:: Set Default Install Directory
set "ENERGI3_HOME=C:\energi3"

@echo Enter Full Path where you want to install Energi3 Node.
:checkhome
  set "CHK_HOME=Y"
  set /p ENERGI3_HOME="Enter Install Path (Default: %ENERGI3_HOME%): "
  set /p CHK_HOME="Is Install path correct: %ENERGI3_HOME% (Y/n): "
  if /I not "%CHK_HOME%" == "Y" goto checkhome

echo Energi Node v3.x will be installed in %ENERGI3_HOME%

:: Confirm Mainnet or Testnet
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

:: Set Directories
:setdir
set "BIN_DIR=%ENERGI3_HOME%\bin"
set "JS_DIR=%ENERGI3_HOME%\js"
set "PW_DIR=%ENERGI3_HOME%\securefolder"
set "TMP_DIR=%ENERGI3_HOME%\tmp"
set "CONF_DIR=%userprofile%\AppData\Roaming\%DATA_DIR%"

:: Set Executables & Configuration
set "EXE_NAME=energi3.exe"
set "DATA_CONF=energi3.toml"

:: Bootstrap
:: set "BLK_HASH=gsaqiry3h1ho3nh"
:: set BOOTSTRAP_URL="https://www.dropbox.com/s/%BLK_HASH%/blocks_n_chains.tar.gz"

:: Save location of current working directory
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
if Not exist "%TMP_DIR%\" (
  @echo Creating directory: %TMP_DIR%
  md %TMP_DIR%
)

:: Check if Energi3 is installed and version installed
if exist %BIN_DIR%\%EXE_NAME% (
  cd %BIN_DIR%
  set "OLD_VERSION="
  FOR /f "tokens=1*delims=: " %%a IN ('%BIN_DIR%\%EXE_NAME% version ') DO (
   IF "%%a"=="Version" SET "OLD_VERSION=%%b"
  )
  echo Current version of Energi3 installed: %OLD_VERSION%
) else (
  echo Energi3 is not installed in this computer.
)

:: Set for script testing
set "OLD_VERSION=0.5.5"

:: Get current version available from Github
set /p VERSION=<%BIN_DIR%\version.txt
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


::
::  Compares two version numbers and returns the result in the ERRORLEVEL
:: 
:: Returns 1 if version1 > version2
::         0 if version1 = version2
::        -1 if version1 < version2
::
:: The nodes must be delimited by . or , or -
::
:: Nodes are normally strictly numeric, without a 0 prefix. A letter suffix
:: is treated as a separate node
::
:compareVersions  version1  version2
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
  @echo Changing to the %TMP_DIR% folder.
  cd "%TMP_DIR%"

  @echo Downloading utility files.
  if exist "%TMP_DIR%\7za.exe" (
    del "%TMP_DIR%\7za.exe"
  )
  if exist "%TMP_DIR%\util.7z" (
    del "%TMP_DIR%\util.7z"
  )
  TIMEOUT /T 9

  bitsadmin /RESET /ALLUSERS
  bitsadmin /TRANSFER DL7zipAndUtil /DOWNLOAD /PRIORITY FOREGROUND "https://www.dropbox.com/s/kqm6ki3j7kaauli/7za.exe?dl=1" "%TMP_DIR%\7za.exe"  "https://www.dropbox.com/s/x51dx1sg1m9wn7o/util.7z?dl=1" "%TMP_DIR%\util.7z"
  "%TMP_DIR%\7za.exe" x -y "%TMP_DIR%\util.7z" -o"%TMP_DIR%\"

  :: Stop Energi3 if it is running
  :: @echo Get %EXE_NAME% process ID
  :: wmic process where "name='%EXE_NAME%'" get ExecutablePath | findstr %EXE_NAME% > "%TMP_DIR%\pid.tmp"
  :: set /p wallet= < "%TMP_DIR%\pid.tmp"
  :: del "%TMP_DIR%\pid.tmp"

  :: if ["%wallet%"] NEQ [""] (
  ::   for /F "skip=1" %%A in (
  ::     'wmic process where "name='%EXE_NAME%'" get ProcessID'
  ::   ) do (
  ::     echo %%A >> "%TMP_DIR%\pid.txt"
  ::   )
  :: )

  :: set /p walletpid= <"%TMP_DIR%\pid.txt"
  :: if exist "%TMP_DIR%\pid.txt" (
  ::   del "%TMP_DIR%\pid.txt"
  ::   @echo Stop %DATA_DIR% wallet.
  ::   TIMEOUT /T 3
  ::   @echo "taskkill /PID %walletpid% /F"
  ::   taskkill /PID %walletpid% /F
  :: )

  @echo Download Energi3 Node application...
  TIMEOUT /T 9

  @echo Downloading Public Test Energi Core Node
  "%TMP_DIR%\wget.exe" --no-check-certificate "https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi3/%VERSION%/energi3-windows-4.0-amd64.exe?dl=1" -O "%BIN_DIR%\energi3.exe"

  @echo Downloading staking batch script
  "%TMP_DIR%\wget.exe" --no-check-certificate "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/run_windows.bat" "%BIN_DIR%\run_windows.bat"
  
  @echo Downloading masternode batch script
  "%TMP_DIR%\wget.exe" --no-check-certificate "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/run_mn_windows.bat" "%BIN_DIR%\run_mn_windows.bat"

  @echo Downloading passwd.txt file
  "%TMP_DIR%\wget.exe" --no-check-certificate "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/passwd.txt" "%PW_DIR%\passwd.txt"

  @echo Downloading utils.js JavaScript file
  "%TMP_DIR%\wget.exe" --no-check-certificate "https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/js/utils.js" "%JS_DIR%\utils.js"

  cd %BIN_DIR%\bin
  goto :installFinish


:OLDVERSION
  @echo Current version %OLD_VERSION% is newer.  Nothing to install.
  goto :installFinish


:SAMEVERSION
  @echo Versions are the same.  Nothing to install.
  goto :installFinish


:installFinish

::@echo Please wait for the snapshot to download.
::"%TMP_DIR%\wget.exe" --no-check-certificate "https://www.dropbox.com/s/%BLK_HASH%/blocks_n_chains.tar.gz?dl=1" -O "%CONF_DIR%\blocks_n_chains.tar.gz"

::if Not exist "%CONF_DIR%\blocks_n_chains.tar.gz" (
::  bitsadmin /RESET /ALLUSERS
::  bitsadmin /TRANSFER blocks_n_chains.tar.gz /DOWNLOAD /PRIORITY FOREGROUND "https://www.dropbox.com/s/%BLK_HASH%/blocks_n_chains.tar.gz?dl=1" "%CONF_DIR%\blocks_n_chains.tar.gz"
::)

::"%TMP_DIR%\7za.exe" e -y "%CONF_DIR%\blocks_n_chains.tar.gz" -o"%CONF_DIR%\"
::if Not exist "%CONF_DIR%\blocks_n_chains.tar" (
::  echo Download of the snapshot failed.
::  pause
::  EXIT
::)

:createshortcut
if not exist "%userprofile%\Desktop\Energi3.lnk" (
  set _a=%
  set _b=AppData
  echo set WshShell = WScript.CreateObject("WScript.Shell") > CreateShortcut.vbs
  echo sLinkFile = "%userprofile%\Desktop\Energi3.lnk" >> CreateShortcut.vbs
  echo Set oMyShortCut = WshShell.CreateShortcut(sLinkFile) >> CreateShortcut.vbs
  echo oMyShortcut.IconLocation = "%BIN_DIR%\energi.ico" >> CreateShortcut.vbs
  if /I "%isMainnet%"=="Y" (
    echo oMyShortCut.TargetPath = "C:\Windows\System32\cmd.exe /c %BIN_DIR%\%EXE_NAME% console 2> %_a%%_b%%_a%\%DATA_DIR%\debug.log" >> CreateShortcut.vbs
  ) else (
    echo oMyShortCut.TargetPath = "C:\Windows\System32\cmd.exe /c %BIN_DIR%\%EXE_NAME% --testnet console 2> %_a%%_b%%_a%\%DATA_DIR%\debug.log" >> CreateShortcut.vbs
  )
  echo oMyShortCut.WorkingDirectory = "%BIN_DIR%" >> CreateShortcut.vbs
  echo oMyShortCut.Save >> CreateShortcut.vbs
  cscript CreateShortcut.vbs
  del CreateShortcut.vbs
  echo Energi3 shortcut created on Desktop
) else (
  echo Energi3 shortcut exists on Desktop.
  echo Nothing created.  Check to make sure it is up to date
)

:: Remove Energi 2.x network files
@echo Do you want to remove Energi 2.x blockchain files.
set /p RemoveEnergi2="Y/N: "

:energi2conf
if /I "%RemoveEnergi2%"=="Y" (
  TIMEOUT /T 9
  set "ENERGI2_CONF_DIR=%AppData%\EnergiCore"
  if Not exist "%ENERGI2_CONF_DIR%\" (
    echo "Where is your Energi 2.x Configuration Directory
  
    if Not exist "%ENERGI2_CONF_DIR%\" (
      goto energi2conf
    )
  )
  rmdir "%ENERGI2_CONF_DIR%\blocks\" /s /q
  rmdir "%ENERGI2_CONF_DIR%\chainstate\" /s /q
  rmdir "%ENERGI2_CONF_DIR%\database\" /s /q
  del "%ENERGI2_CONF_DIR%\.lock"
  del "%ENERGI2_CONF_DIR%\banlist.dat"
  del "%ENERGI2_CONF_DIR%\db.log"
  del "%ENERGI2_CONF_DIR%\debug.log"
  del "%ENERGI2_CONF_DIR%\fee_estimates.dat"
  del "%ENERGI2_CONF_DIR%\governance.dat"
  del "%ENERGI2_CONF_DIR%\mempool.dat"
  del "%ENERGI2_CONF_DIR%\mncache.dat"
  del "%ENERGI2_CONF_DIR%\mnpayments.dat"
  del "%ENERGI2_CONF_DIR%\netfulfilled.dat"
  del "%ENERGI2_CONF_DIR%\peers.dat"
  del "%ENERGI2_CONF_DIR%\blocks_n_chains.tar.gz"
  del "%ENERGI2_CONF_DIR%\blocks_n_chains.tar"
  @echo Done removing Energi 2.x files.
)

:utilCleanup
@echo Cleanup utilities files.
TIMEOUT /T 3
del "%TMP_DIR%\7za.exe"
del "%TMP_DIR%\util.7z"
del "%TMP_DIR%\grep.exe"
del "%TMP_DIR%\libeay32.dll"
del "%TMP_DIR%\libiconv2.dll"
del "%TMP_DIR%\libintl3.dll"
del "%TMP_DIR%\libssl32.dll"
del "%TMP_DIR%\pcre3.dll"
del "%TMP_DIR%\regex2.dll"
del "%TMP_DIR%\wget.exe"

:: @echo Move back to Initial Working Directory.
:: cd "%mycwd%"

:: @echo Starting %DATA_DIR%
:: if ["%wallet%"] == [""] (
::   start "" "%DEFAULT_EXE_LOCATION%"
::   echo Running %DEFAULT_EXE_LOCATION%
:: ) else (
::   start "" "%wallet%"
::   echo Running %wallet%
:: )
:: @echo Please wait for the wallet to start and for the wallet to rescan.
:: pause

@echo Done
