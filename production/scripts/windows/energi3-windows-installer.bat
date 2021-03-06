@echo OFF

::####################################################################
:: Copyright (c) 2019
:: All rights reserved.
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
::
:: Desc: Batch script to download and setup Energi 3.x on Windows PC.
::       The script will upgrade an existing installation.
::
:: Download and run the batch script to:
:: explorer.exe https://raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/windows/energi3-windows-installer.bat
::####################################################################

setlocal ENABLEEXTENSIONS

:: Check OS Architecture (32-bit or 64-bit)
wmic os get osarchitecture | findstr bit > "%userprofile%\osarchitecture.txt"
set /p osarch= < "%userprofile%\osarchitecture.txt"
del "%userprofile%\osarchitecture.txt"
:: remove whitespace
set osarch=%osarch: =%
if "%osarch%" NEQ "64-bit" (
  @echo "Windows x86 %osarch% is not supported"
  exit /b
)

:: Set PATH variable
::set "PATH=%PATH;C:\Program Files (x86)\Common Files\Oracle\Java\javapath;%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0\;%userprofile%\AppData\Local\Microsoft\WindowsApps"
set "PATH=%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0\;%windir%\System32\OpenSSH\;%userprofile%\AppData\Local\Microsoft\WindowsApps;%PATH%"

:: Set Default Install Directory
set "ENERGI3_HOME=%ProgramFiles%\Energi3"

@echo Enter Full Path where you want to install Energi3 Node.
:checkhome
  set "CHK_HOME=Y"
  set /p ENERGI3_HOME="Enter Install Path (Default: %ENERGI3_HOME%): "
  set /p CHK_HOME="Is Install path correct: %ENERGI3_HOME% (Y/n): "
  if /I not "%CHK_HOME%" == "Y" goto :checkhome

@echo Energi Node v3.x will be installed in %ENERGI3_HOME%

:: Confirm Mainnet or Testnet
:setNetwork
  set "isMainnet=Y"
::  set /p isMainnet="Are you setting up Mainnet [Y]/n: "

  if /I "%isMainnet%" == "Y" (
    set "DATA_DIR=EnergiCore3"
    echo The application will be setup for Mainnet
    goto :setdir
  )

  if /I "%isMainnet%" == "N" (
    set "DATA_DIR=EnergiCore3\testnet"
    echo The application will be setup for Testnet
    goto :setdir
  )

:: Set Directories
:setdir
set "BIN_DIR=%ENERGI3_HOME%\bin"
set "JS_DIR=%ENERGI3_HOME%\js"
set "PW_DIR=%ENERGI3_HOME%\secure"
set "TMP_DIR=%ENERGI3_HOME%\tmp"
set "CONF_DIR=%userprofile%\AppData\Roaming\%DATA_DIR%"

:: Set Executables & Configuration
set "EXE_NAME=energi3.exe"
set "DATA_CONF=energi3.toml"

:: Bootstrap Settings
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
  md "%BIN_DIR%"
)
if Not exist "%JS_DIR%\" (
  @echo Creating directory: %JS_DIR%
  md "%JS_DIR%"
)
if Not exist "%TMP_DIR%\" (
  @echo Creating directory: %TMP_DIR%
  md "%TMP_DIR%"
)

:: Add Application specific PATH
set "PATH=%PATH%;%BIN_DIR%;%TMP_DIR%"

:: Download utilities
:downloadutils
@echo Changing to the %TMP_DIR% folder.
cd "%TMP_DIR%"

@echo Downloading utility files.
if exist "%TMP_DIR%\7za.exe" (
  del "%TMP_DIR%\7za.exe"
)
if exist "%TMP_DIR%\util.7z" (
  del "%TMP_DIR%\util.7z"
)

:: runas with administrator TrustLevel
runas /TrustLevel:0x30000 "bitsadmin /RESET /ALLUSERS"
bitsadmin /TRANSFER DL7zipAndUtil /DOWNLOAD /PRIORITY FOREGROUND "https://www.dropbox.com/s/kqm6ki3j7kaauli/7za.exe?dl=1" "%TMP_DIR%\7za.exe"  "https://www.dropbox.com/s/x51dx1sg1m9wn7o/util.7z?dl=1" "%TMP_DIR%\util.7z"
"%TMP_DIR%\7za.exe" x -y "%TMP_DIR%\util.7z" -o"%TMP_DIR%\"
bitsadmin /TRANSFER DLwget /DOWNLOAD /PRIORITY FOREGROUND "https://eternallybored.org/misc/wget/1.20.3/64/wget.exe" "%TMP_DIR%\wget.exe"

::certutil.exe -urlcache -split -f "https://www.dropbox.com/s/kqm6ki3j7kaauli/7za.exe?dl=1" "%TMP_DIR%\7za.exe"
::certutil.exe -urlcache -split -f "https://eternallybored.org/misc/wget/1.20.3/64/wget.exe?dl=1" "%TMP_DIR%\wget.exe"
::"%TMP_DIR%\7za.exe" x -y "%TMP_DIR%\wget.zip" -o"%TMP_DIR%\"

@echo Downloading jq
"%TMP_DIR%\wget.exe" --no-check-certificate --progress=bar:force:noscroll "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe?dl=1" -O "%BIN_DIR%\jq.exe"

:: Check if Energi3 is installed and version installed
if exist "%BIN_DIR%\%EXE_NAME%" (
  cd "%BIN_DIR%"
  set "RUN_VERSION="
  FOR /f "tokens=1*delims=: " %%a IN ('"%BIN_DIR%\%EXE_NAME%" version ') DO (
   IF "%%a"=="Version" SET "RUN_VERSION=%%b"
  )
  set RUN_VERSION=%RUN_VERSION:-=&rem.%
  @echo Current version of Energi3 installed: %RUN_VERSION%
) else (
  @echo Energi3 is not installed in %BIN_DIR% of this computer.
  set "NEWINSTALL=Y"
  goto :CHECKGITVER
)
pause
:: Set for script testing
::set "RUN_VERSION=0.5.5"

:: Check latest release version available from Github
:: https://api.github.com/repos/energicryptocurrency/energi3/releases/latest
:: tag_name
:: browser_download_url


:CHECKGITVER
cd "%TMP_DIR%"
curl -o "%TMP_DIR%\gitversion.txt" "https://api.github.com/repos/energicryptocurrency/energi3/releases/latest" 

:: set "GIT_VERSION="
::  FOR /f "tokens=1*delims=: " %%a IN ( gitversion.txt ) DO (
::   IF %%a=="tag_name" SET GIT_VERSION=%%b
::  )
  
type "%TMP_DIR%\gitversion.txt" | "%BIN_DIR%\jq.exe" -r .tag_name > "%TMP_DIR%\gitversion.tmp"
set /p GIT_VERSION "%TMP_DIR%\gitversion.tmp"
del "%TMP_DIR%\gitversion.tmp"
set GIT_VERSION=%GIT_VERSION:v=%
set GIT_VERSION=%GIT_VERSION:"=%
set GIT_VERSION=%GIT_VERSION:,=%

type "%TMP_DIR%\gitversion.txt" | "%BIN_DIR%\jq.exe" -r ".assets | .[] | select(.name==\"energi3-windows-4.0-amd64.exe\") .browser_download_url" > "%TMP_DIR%\appurl.tmp"
set /p APPURL= < "%TMP_DIR%\appurl.tmp"
del "%TMP_DIR%\appurl.tmp"
del "%TMP_DIR%\gitversion.txt"

echo GIT_VERSION: %GIT_VERSION%
if /I "%NEWINSTALL%" == "Y" goto :NEWVERSION

:: Compare Versions
call :testVersions  %GIT_VERSION%  %VERSION%
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

::
:: Main program to download and setup Energi 3.x
::
:NEWVERSION
  @echo Download Energi3 Node Version: %GIT_VERSION%
  TIMEOUT /T 3

  @echo Downloading Public Test Energi Core Node
  :: "%TMP_DIR%\wget.exe" --no-check-certificate --progress=bar:force:noscroll "%APPURL%https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi3/%GIT_VERSION%/energi3-windows-4.0-amd64.exe?dl=1" -O "%BIN_DIR%\energi3.exe"
  
  "%TMP_DIR%\wget.exe" --no-check-certificate --progress=bar:force:noscroll "%APPURL%?dl=1" -O "%BIN_DIR%\energi3.exe"

  @echo Downloading staking batch script
  "%TMP_DIR%\wget.exe" --no-check-certificate --progress=bar:force:noscroll "https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_windows.bat?dl=1" -O "%BIN_DIR%\run_windows.bat"
  
  @echo Downloading Energi icon
  "%TMP_DIR%\wget.exe" --no-check-certificate --progress=bar:force:noscroll "https://github.com/zalam003/EnergiCore3/blob/master/production/scripts/windows/energi3.ico?dl=1" -O "%BIN_DIR%\energi.ico"

  @echo Downloading masternode batch script
  "%TMP_DIR%\wget.exe" --no-check-certificate --progress=bar:force:noscroll "https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/scripts/run_mn_windows.bat?dl=1" -O "%BIN_DIR%\run_mn_windows.bat"

  @echo Downloading utils.js JavaScript file
  "%TMP_DIR%\wget.exe" --no-check-certificate --progress=bar:force:noscroll "https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest/js/utils.js?dl=1" -O "%JS_DIR%\utils.js"

  cd "%BIN_DIR%"
  goto :bootstrap


:OLDVERSION
  @echo Current version %RUN_VERSION% is newer.  Nothing to install.
  goto :bootstrap


:SAMEVERSION
  @echo Versions are the same.  Nothing to install.
  goto :bootstrap


:bootstrap
::@echo Please wait for the snapshot to download.
:: --no-check-certificate
::"%TMP_DIR%\wget.exe" -4q -o- "%BOOTSTRAP_URL%?dl=1" -O "%CONF_DIR%\blocks_n_chains.tar.gz"

::if Not exist "%CONF_DIR%\blocks_n_chains.tar.gz" (
::  bitsadmin /RESET /ALLUSERS
::  bitsadmin /TRANSFER blocks_n_chains.tar.gz /DOWNLOAD /PRIORITY FOREGROUND "%BOOTSTRAP_URL%?dl=1" "%CONF_DIR%\blocks_n_chains.tar.gz"
::)

::"%TMP_DIR%\7za.exe" e -y "%CONF_DIR%\blocks_n_chains.tar.gz" -o"%CONF_DIR%\"
::if Not exist "%CONF_DIR%\blocks_n_chains.tar" (
::  echo Download of the snapshot failed.
::  pause
::  EXIT
::)

:createshortcut
@echo Set WshShell = WScript.CreateObject("WScript.Shell") > "%TMP_DIR%\CreateShortcut.vbs"
@echo sLinkFile = "%userprofile%\Desktop\Energi3.lnk" >> "%TMP_DIR%\CreateShortcut.vbs"
@echo Set oMyShortCut = WshShell.CreateShortcut(sLinkFile) >> "%TMP_DIR%\CreateShortcut.vbs"
@echo oMyShortcut.IconLocation = "%BIN_DIR%\energi.ico" >> "%TMP_DIR%\CreateShortcut.vbs"
if /I "%isMainnet%"=="Y" (
  @echo oMyShortCut.TargetPath = "%BIN_DIR%\run_windows.bat" >> "%TMP_DIR%\CreateShortcut.vbs"
) else (
  @echo oMyShortCut.TargetPath = "%BIN_DIR%\run_windows.bat" >> "%TMP_DIR%\CreateShortcut.vbs"
)
@echo oMyShortCut.WorkingDirectory = "c:\Program Files\Energi3\bin" >> "%TMP_DIR%\CreateShortcut.vbs"
@echo oMyShortCut.Save >> "%TMP_DIR%\CreateShortcut.vbs"

if not exist "%userprofile%\Desktop\Energi3.lnk" (
  cscript "%TMP_DIR%\CreateShortcut.vbs"
  @echo Energi3 shortcut created on Desktop
  ) else (
  @echo Shortcut already exists
) 
:: del "%TMP_DIR%\CreateShortcut.vbs"

:: Remove Energi 2.x network files
::set "RemoveEnergi2=N"
::set /p RemoveEnergi2="Do you want to remove Energi 2.x blockchain files (y/N): "
::if /I "%isMainnet%"=="Y" (
::  set "ENERGI2_CONF_DIR=%AppData%\EnergiCore"
::  ) else (
::  set "ENERGI2_CONF_DIR=%AppData%\EnergiCore\testnet"
::)

:energi2conf
if /I "%RemoveEnergi2%"=="Y" (
  if Not exist "%ENERGI2_CONF_DIR%\" (
    @echo Default configuration directory %ENERGI2_CONF_DIR% does not exist.
    set /p ENERGI2_CONF_DIR="Enter location of Energi 2.x config directory: "
    if Not exist "%ENERGI2_CONF_DIR%\" (
      goto :energi2conf
      ) else (
	  goto :utilCleanup
	)
  )
  @echo Deleting blockchain files from %ENERGI2_CONF_DIR%...
  :: TIMEOUT /T 9
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
  @echo Cleanup utilities files downloaded for setup from %TMP_DIR%
  :: TIMEOUT /T 3
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

:: Set keystore password
set "SETPWD=N"
@echo You can set password of your keystore account for automated start of staking/mining.
@echo It will create a secure/hidden file with the password.
set /p SETPWD="Do you want to save your password? (y/N): "
if /I "%SETPWD%" == "Y" (
  if Not exist "%PW_DIR%\" (
    @echo Creating hidden directory: %PW_DIR%
    md "%PW_DIR%"
    attrib +r +h +s "%PW_DIR%"
  )
  cd "%PW_DIR%"
  :setpassword
	set /p ACCTPASSWD1="Enter your keystore account password: "
	set /p ACCTPASSWD2="Re-enter your keystore account password: "
	if "%ACCTPASSWD1%" NEQ "%ACCTPASSWD2%" (
	  @echo Passwords do not match. Try again.
	  goto :setpassword
	)
	echo Password is %ACCTPASSWD1%
	echo %ACCTPASSWD1% 1> securefile.txt
	attrib +r %PW_DIR%\securefile.txt
)

@echo Move back to Initial Working Directory.
cd "%mycwd%"

:: Color
:: Background      Text
:: 0 = Black       8 = Gray
:: 1 = Blue        9 = Light Blue
:: 2 = Green       A = Light Green
:: 3 = Aqua        B = Light Aqua
:: 4 = Red         C = Light Red
:: 5 = Purple      D = Light Purple
:: 6 = Yellow      E = Light Yellow
:: 7 = White       F = Bright White

color 0A
cls
@echo.
@echo.
::@echo       ___
::@echo      /\  \
::@echo     /::\  \
::@echo    /:/\:\__\
::@echo   /:/ /:/ _/_
::@echo  /:/ /:/ /\__\  ______ _   _ ______ _____   _____ _____ ____  
::@echo  \:\ \/ /:/  / |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
::@echo   \:\  /:/  /  | |__  |  \| | |__  | |__) | |  __  | |   __) |
::@echo    \:\/:/  /   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
::@echo     \::/  /    | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
::@echo      \/__/     |______|_| \_|______|_|  \_\\_____|_____|____/ 
::@echo.
@echo.
color 0F
@echo Congratulations! Energi Node Version %GIT_VERSION% is installed on this computer
@echo Install directory is: %ENERGI3_HOME%
if %isMainnet% == y (
  @echo Test application: %ENERGI3_HOME%\bin\energi3 console
  ) else (
  @echo Test application: %ENERGI3_HOME%\bin\energi3 --testnet console
  )
@echo.
@echo Run one of the following scripts after updating parameters:
@echo Staking script:    %ENERGI3_HOME%\bin\run_windows.bat
@echo Masternode script: %ENERGI3_HOME%\bin\run_mn_windows.bat
@echo.


:: End batch script
@echo Done