<h1>This directory has scripts to install and run Gen3 application</h1>

<H2>Install and run on Windows</H2>
To install the app and start scripts run the following from a command window:

```
bitsadmin /transfer DLInstStartScript /download /priority foreground "https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/pubtest_install_windows.bat" "%cd%\pubtest_install_windows.bat"<p>
```
<h3>Run scripts for Windows</h3>
- run_windows.bat: Start staking server on Windows<br>
- run_mn_windows.bat: Start masternode on Windows<br>
- passwd.txt: File with passphrase to start masternode<br>
<br>

<h2>Install and run on MacOS</h2>
To install the app and start scripts run the following from a Terminal window:

```
bash -i <( curl -sL https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/pubtest_install_macos.sh )
```
<h3>Run scripts for MacOS</h3>
- run_macos.sh: Start staking server on MacOS<br>
- run_mn_macos.sh: Start masternode on MacOS<br>
<br>

<h2>Install and run on Linux</h2>
To install the app and start scripts run the following from a Terminal window:

```
bash -i <( curl -sL https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/pubtest_install_linux.sh )
```
<h3>Run scripts for Linux</h3>
- run_linux.sh: Start staking server on Linux<br>
- run_mn_linux.sh: Start masternode on Linux<br>
- run_screen_linux.sh: Start masternode in ``screen`` on Linux<br>
