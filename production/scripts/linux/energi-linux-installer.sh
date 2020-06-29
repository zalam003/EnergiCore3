#!/bin/bash

######################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Batch script to download and setup Energi v3 on Linux. The
#         script will upgrade an existing installation. 
# 
# Version:
#   1.2.9  20200309  ZA Initial Script
#   1.2.12 20200311  ZA added removedb to upgrade
#   1.2.14 20200312  ZA added create keystore if not downloading
#   1.2.15 20200423  ZA bug in _add_nrgstaker
#   1.3.0  20200521  ZA migrate to energi binary name; merge RPi
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts/linux/energi3-linux-installer.sh)" ; source ~/.bashrc
```
'
######################################################################


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Global Variables
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

# Check if we have enough memory
if [[ $(LC_ALL=C free -m | awk '/^Mem:/{print $2}') -lt 850 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# OS Settings
export DEBIAN_FRONTEND=noninteractive 

# Locations of Repositories and Guide
API_URL="https://api.github.com/repos/energicryptocurrency/energi3/releases/latest"
# Production
if [[ -z ${BASE_URL} ]]
then
  BASE_URL="raw.githubusercontent.com/energicryptocurrency/energi3-provisioning/master/scripts"
fi
#==> For testing set environment variable
#BASE_URL="raw.githubusercontent.com/zalam003/EnergiCore3/master/production/scripts"
SCRIPT_URL="${BASE_URL}/linux"
TP_URL="${BASE_URL}/thirdparty"
DOC_URL="https://docs.energi.software"
S3URL="https://s3-us-west-2.amazonaws.com/download.energi.software/releases/energi3"

# Energi Bootstrap Settings
export BOOTSTRAP_URL="https://github.com/energicryptocurrency/energi3-provisioning/releases/download/bootstrap/gen3-chaindata.tar.gz"

# Set Executables & Configuration
export ENERGI_EXE=energi
export ENERGI_CONF=energi.toml
export ENERGI_IPC=energi3.ipc

# Set colors
BLUE=`tput setaf 4`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 2`
NC=`tput sgr0`

### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Functions
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

_os_arch () {
  # Check Architecture
  OSNAME=`grep ^NAME /etc/os-release | awk -F\" '{ print $2 }'`
  OSVERSIONLONG=`grep ^VERSION_ID /etc/os-release | awk -F\" '{ print $2 }'`
  OSVERSION=`echo ${OSVERSIONLONG} | awk -F\. '{ print $1 }'`
  echo -n "${OSNAME} ${OSVERSIONLONG} is  "
  if [ "${OSNAME}" = "Ubuntu" ] && [ ${OSVERSION} -ge 18 ]
  then
    echo "${GREEN}supported${NC}"
  elif [ "${OSNAME}" = "Raspbian GNU/Linux" ]
  then
    echo "${GREEN}supported${NC}"
  else
    echo "${RED}not supported${NC}"
    exit 0
  fi
  
  echo -n "OS architecture "
  OSPLATFORM=`uname -m`
  if [ "${OSPLATFORM}" = "x86_64" ]
  then
    echo "${GREEN}${OSPLATFORM} is supported${NC}"
    OSARCH=amd64
    sleep 0.3
  elif [ "${OSPLATFORM}" = "i686" ]
  then
    echo "${GREEN}${OSPLATFORM} is supported${NC}"
    OSARCH=i686
    sleep 0.3
  elif [ "${OSPLATFORM}" = "aarch64" ]
  then
    echo "${GREEN}${OSPLATFORM} is supported${NC}"
    OSARCH=armv8
    sleep 0.3
  elif [ "${OSPLATFORM}" = "armv7l" ]
  then
    echo "${GREEN}${OSPLATFORM} is supported${NC}"
    OSARCH=armv7
    sleep 0.3
  else
    echo "${RED}${OSPLATFORM} is not supported with the installer${NC}"
    echo "Please check our website for supported platforms."
    echo
    echo "   https://docs.energi.software/en/downloads/core-node"
    echo
    exit 0
  fi
  
}

_check_runas () {

  # Who is running the script
  # If root no sudo required
  # If user has sudo privilidges, run sudo when necessary

  RUNAS=`whoami`
  
  if [[ $EUID = 0 ]]
  then
    SUDO=""
  else
    ISSUDOER=`getent group sudo | grep ${RUNAS}`
    if [ ! -z "${ISSUDOER}" ]
    then
      SUDO='sudo'
    else
      echo "User ${RUNAS} does not have sudo permissions."
      echo "Run ${BLUE}sudo ls -l${NC} to set permissions if you know the user ${RUNAS} has sudo previlidges"
      echo "and then rerun the script"
      echo "Exiting script..."
      sleep 3
      exit 0
    fi
  fi
}

_add_nrgstaker () {
  
  # Check if user nrgstaker exists if not add the user
  
  CHKPASSWD=`grep ${USRNAME} /etc/passwd`
  
  if [ "${CHKPASSWD}" == "" ]
  then
      if [ ! -x "$( command -v pwgen )" ]
      then
        echo "Installing missing package to generate random password"
        ${SUDO} apt-get install -yq pwgen
      fi
      
      USRPASSWD=`pwgen 10 1`
      clear
      echo
      echo "The following username / password is needed for future login."
      echo "Please write down the following before continuing!!!"
      echo "  Username: ${GREEN}${USRNAME}${NC}"
      echo "  Password: ${GREEN}${USRPASSWD}${NC}"
      echo
      REPLY=''
      read -p "Did you write down the username and password? y/[n]: "
      REPLY=${REPLY,,} # tolower
      if [[ "${REPLY}" == "n" ]] || [[ -z "${REPLY}" ]]
      then
        echo
        echo "Exiting script without creating the user account!!!"
        echo
        exit 0
      fi
      
      ${SUDO} adduser --gecos "Energi Staking Account" --disabled-password --quiet ${USRNAME}
      echo -e "${USRPASSWD}\n${USRPASSWD}" | ${SUDO} passwd ${USRNAME} 2>/dev/null
  fi

  export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
  export ENERGI_HOME=${USRHOME}/energi
  
  ${SUDO} usermod -aG sudo ${USRNAME}
  touch /home/${USRNAME}/.sudo_as_admin_successful
  chmod 644 /home/${USRNAME}/.sudo_as_admin_successful
  
  if [[ ! -f /etc/sudoers.d/${USRNAME} ]]
  then
    cat << SUDO_CONF | sudo tee /etc/sudoers.d/${USRNAME} >/dev/null
${USRNAME} ALL=NOPASSWD: ALL
SUDO_CONF

  fi
  
  if [[ ${EUID} = 0 ]]
  then
      chown ${USRNAME}:${USRNAME} /home/${USRNAME}/.sudo_as_admin_successful
  fi
  
  # Add PATH variable for Energi
  CHKBASHRC=`grep "Energi3 PATH" "${USRHOME}/.bashrc"`
  if [ ! -z "${CHKBASHRC}" ]
  then
    sed -i 's/Energi3/Energi/g' "${USRHOME}/.bashrc"
    sed -i 's/energi3/energi/g' "${USRHOME}/.bashrc"
    source ${USRHOME}/.bashrc
  fi
  
  CHKBASHRC=`grep "Energi PATH" "${USRHOME}/.bashrc"`
  if [ -z "${CHKBASHRC}" ]
  then
    echo "" >> "${USRHOME}/.bashrc"
    echo "# Energi PATH" >> "${USRHOME}/.bashrc"
    echo "export PATH=\${PATH}:\${HOME}/energi/bin" >> "${USRHOME}/.bashrc"
    echo
    echo "  .bashrc updated with PATH variable"
    if [[ $EUID != 0 ]]
    then
      source ${USRHOME}/.bashrc
    fi
  else
    echo "  .bashrc up to date. Nothing to add"
  fi
  
  echo
  echo "${GREEN}*** User ${USRNAME} created and added to sudoer group                       ***${NC}"
  echo "${GREEN}*** User ${USRNAME} will be used to install the software and configurations ***${NC}"
  sleep 0.3
  
}

_check_install () {

  # Check if run as root or user has sudo privilidges
  
  _check_runas
  
  CHKV3USRTMP=/tmp/chk_v3_usr.tmp
  >${CHKV3USRTMP}
  ${SUDO} find /home -name nodekey | awk -F\/ '{print $3}' > ${CHKV3USRTMP}
  ${SUDO} find /root -name nodekey | awk -F\/ '{print $3}' >> ${CHKV3USRTMP}
  V3USRCOUNT=`wc -l ${CHKV3USRTMP} | awk '{ print $1 }'`
  
  case ${V3USRCOUNT} in
  
    0)
      
      # New Installation:
      #   * No energi3.ipc file on the computer
      #   * No energi.conf or energid on the computer
      #
      echo "${YELLOW}Not installed${NC}"
      echo

      # Set username
      USRNAME=nrgstaker
      INSTALLTYPE=new
      
      _add_nrgstaker
      ;;
      
    1)
      
      # Upgrade existing version of Energi 3:
      #   * One instance of Energi3 is already installed
      #   * nodekey file exists
      #   * Version on computer is older than version in Github
      
      export USRNAME=`cat ${CHKV3USRTMP}`
      INSTALLTYPE=upgrade
      echo "The script will upgrade to the latest version of energi from Github"
      echo "if available as user: ${GREEN}${USRNAME}${NC}"
      sleep 0.3
      
      export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
      export ENERGI_HOME=${USRHOME}/energi
      ;;
  
    *)
      
      # Upgrade existing version of Energi:
      #   * More than one instance of Energi is already installed
      #   * energi3.ipc file exists
      #   * Version on computer is older than version in Github
      #   * User selects which instance to upgrade
      
      I=1
      for U in `cat ${CHKV3USRTMP}`
      do
        #echo "${U}"
        USR[${I}]=${U}
        echo "${I}: ${USR[${I}]}"
        ((I=I+1))
        if [ ${I} = ${V3USRCOUNT} ]
        then
          break
        fi
      done
      REPLY=""
      read -p "Select with user name to upgrade: " REPLY
      
      if [ ${REPLY} -le ${V3USRCOUNT} ]
      then
        export USRNAME=${USR[${REPLY}]}
        
        if [[ "${USRNAME}" -ne "${RUNAS}" ]]
        then
          clear
          echo "You have to run the script as root or ${USRNAME}"
          echo "Login as ${USRNAME} and run the script again"
          echo "Exiting script..."
          exit 0
        fi
              
        INSTALLTYPE=upgrade
        
        export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
        export ENERGI_HOME=${USRHOME}/energi

      else
        echo "${RED}Invalid entry:${NC} Enter a number less than or equal to ${V3USRCOUNT}"
        echo "               Starting over"
        _check_install
      fi
      
      echo "Upgrading Energi as ${USRNAME}"
      ;;
  
  esac
  
  # Clean-up temporary file
  rm ${CHKV3USRTMP}

}

_setup_appdir () {

  # Setup application directories if does not exist
  
  echo "Energi will be installed in ${ENERGI_HOME}"
  sleep 0.5
  # Set application directories
  export BIN_DIR=${ENERGI_HOME}/bin
  export ETC_DIR=${ENERGI_HOME}/etc
  export JS_DIR=${ENERGI_HOME}/js
  export PW_DIR=${ENERGI_HOME}/.secure
  export TMP_DIR=${ENERGI_HOME}/tmp

  # Create directories if it does not exist
  if [ ! -d ${BIN_DIR} ]
  then
    echo "    Creating directory: ${BIN_DIR}"
    mkdir -p ${BIN_DIR}
  fi
  if [ ! -d ${ETC_DIR} ]
  then
    echo "    Creating directory: ${ETC_DIR}"
    mkdir -p ${ETC_DIR}
  fi
  if [ ! -d ${JS_DIR} ]
  then
    echo "    Creating directory: ${JS_DIR}"
    mkdir -p ${JS_DIR}
  fi
  if [ ! -d ${TMP_DIR} ]
  then
    echo "    Creating directory: ${TMP_DIR}"
    mkdir -p ${TMP_DIR}
  fi
  
  echo
  echo "Changing ownership of ${ENERGI_HOME} to ${USRNAME}"
  if [[ ${EUID} = 0 ]]
  then
    chown -R ${USRNAME}:${USRNAME} ${ENERGI_HOME}
  fi
  
}

_set_ismainnet () {

  # Default: Mainnet
  # If -t or --testnet argument is passed, isMainnet=n$
  
  if [[ "${INSTALLTYPE}" == "new" ]]
  then
    if [[ "${isMainnet}" == 'y' ]] || [[ -z "${isMainnet}" ]]
    then
      export CONF_DIR=${USRHOME}/.energicore3
      export FWPORT=39797
      export APPARG=''
      echo "Core Node will be setup for Mainnet"
    else
      export CONF_DIR=${USRHOME}/.energicore3/testnet
      export APPARG='--testnet'
      export FWPORT=49797
      echo "Core Node will be setup for Testnet"
    fi

  elif [[ "${INSTALLTYPE}" == "upgrade" ]]
  then
    if [ ! -d "${USRNAME}/.energicore3/testnet" ]
    then
      export CONF_DIR=${USRHOME}/.energicore3
      export FWPORT=39797
      echo "Core Node will be setup for Mainnet"
    else
      export CONF_DIR=${USRHOME}/.energicore3/testnet
      export FWPORT=49797
      echo "Core Node will be setup for Testnet"
    fi

  fi
  echo
  sleep 0.3
}

_install_apt () {

  # Check if any apt packages need installing or upgrade
  # Setup server to auto updating security related packages automatically
  
  if [ ! -x "$( command -v aria2c )" ] || [ ! -x "$( command -v unattended-upgrade )" ] || [ ! -x "$( command -v ntpdate )" ] || [ ! -x "$( command -v google-authenticator )" ] || [ ! -x "$( command -v php )" ] || [ ! -x "$( command -v jq )" ]  || [ ! -x "$( command -v qrencode )" ]
  then
    echo
    echo "Updating linux first."
    echo "    Running apt-get update."
    sleep 1
    ${SUDO} apt-get update -yq 2> /dev/null
    echo "    Running apt-get upgrade."
    sleep 1
    ${SUDO} apt-get upgrade -yq 2> /dev/null
    echo "    Running apt-get dist-upgrade."
    sleep 1
    ${SUDO} apt-get -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade 2> /dev/null

    if [ ! -x "$( command -v unattended-upgrade )" ]
    then
      echo "    Running apt-get install unattended-upgrades php ufw."
      sleep 1
      ${SUDO} apt-get install -yq unattended-upgrades php ufw 2> /dev/null
      
      if [ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]
      then
        # Enable auto updating of Ubuntu security packages.
        echo "Setting up server to update security related packages anytime they are available"
        sleep 0.3
        cat << UBUNTU_SECURITY_PACKAGES | ${SUDO} tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
APT::Periodic::Enable "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
UBUNTU_SECURITY_PACKAGES

      fi
    fi
  fi
  
  # Install missing programs if needed.
  if [ ! -x "$( command -v aria2c )" ]
  then
    echo "    Installing missing programs..."
    ${SUDO} apt-get install -yq \
      curl \
      lsof \
      util-linux \
      gzip \
      unzip \
      unrar \
      xz-utils \
      procps \
      htop \
      git \
      gpw \
      bc \
      pv \
      sysstat \
      glances \
      psmisc \
      at \
      subnetcalc \
      net-tools \
      sipcalc \
      python-yaml \
      html-xml-utils \
      apparmor \
      ack-grep \
      pcregrep \
      snapd \
      aria2 \
      dbus-user-session 2> /dev/null
  fi
  
  if [ ! -x "$( command -v jq )" ]
  then
    echo "    Installing jq"
    ${SUDO} apt-get install -yq jq 2> /dev/null
  fi
  echo "    Installing nodejs"
  ${SUDO} apt-get install -yq nodejs 2> /dev/null
  
  echo "    Removing apt files not required"
  ${SUDO} apt autoremove -y 2> /dev/null
  
}

_add_logrotate () {

  # Setup log rotate
  # Logs in $HOME/.energicore3 will rotate automatically when it reaches 100M
  if [ ! -f /etc/logrotate.d/energi ]
  then
    echo "Setting up log maintenance for energi"
    mkdir ${CONF_DIR}/energi3/log
    if [[ ${EUID} = 0 ]]
    then
      chown -R ${USRNAME}:${USRNAME} ${CONF_DIR}/energi3/log
    fi
    sleep 0.3
    cat << ENERGI_LOGROTATE | ${SUDO} tee /etc/logrotate.d/energi >/dev/null
${CONF_DIR}/energi3/log/*.log {
  su ${USRNAME} ${USRNAME}
  rotate 3
  minsize 100M
  copytruncate
  compress
  missingok
}
ENERGI_LOGROTATE

  logrotate -f /etc/logrotate.d/energi
  
  fi
}

_add_systemd () {

  # Setup systemd for autostart

  if [ ! -f /lib/systemd/system/energi.service ]
  then
    echo "Setting up systemctl to automatically start energi after reboot..."
    sleep 0.3
    EXTIP=`curl -s https://ifconfig.me/`
    cat << SYSTEMD_CONF | ${SUDO} tee /lib/systemd/system/energi.service >/dev/null
[Unit]
Description=Energi Core Node Service
After=syslog.target network.target

[Service]
SyslogIdentifier=energi
PermissionsStartOnly=true
Type=simple
Restart=always
RestartSec=5
User=${USRNAME}
Group=${USRNAME}
UMask=0027
ExecStartPre=/bin/mkdir -p ${CONF_DIR}/energi3/log
ExecStartPre=/bin/chown ${USRNAME}:${USRNAME} ${CONF_DIR}/energi3/log
ExecStartPre=/bin/chmod 750 ${CONF_DIR}/energi3/log
ExecStartPre=/bin/touch ${CONF_DIR}/energi3/log/energi_stdout.log
ExecStartPre=/bin/chown ${USRNAME}:${USRNAME} ${CONF_DIR}/energi3/log/energi_stdout.log
ExecStartPre=/bin/chmod 640 ${CONF_DIR}/energi3/log/energi_stdout.log
StandardOutput=file:${CONF_DIR}/energi3/log/energi_stdout.log
StandardError=file:${CONF_DIR}/energi3/log/energi_stdout.log
ExecStart=${BIN_DIR}/energi \
  --datadir ${CONF_DIR} \
  --gcmode archive \
  --maxpeers 128 \
  --masternode \
  --mine \
  --nat extip:${EXTIP} \
  --verbosity 3
WorkingDirectory=${USRHOME}

[Install]
WantedBy=multi-user.target
SYSTEMD_CONF

    if [[ ! -d ${CONF_DIR}/energi3/log ]]
    then
      mkdir -p ${CONF_DIR}/energi3/log
      touch ${CONF_DIR}/energi3/log/energi_stdout.log
      ${SUDO} chown -R ${USRNAME}:${USRNAME} ${CONF_DIR}/energi3/log
    fi
    echo "    Enabling energi service"
    ${SUDO} systemctl enable energi

  fi
}

_install_energi () {

  # Download and install node software and supporting scripts

  # Name of scripts
  JS_SCRIPT=utils.js
  
  # Check Github for URL of latest version
  if [ -z "${GIT_LATEST}" ]
  then
    GITHUB_LATEST=$( curl -s ${API_URL} )
    GIT_VERSION=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
    
    # Extract latest version number without the 'v'
    GIT_LATEST=$( echo ${GIT_VERSION} | sed 's/v//g' )
  fi
 
  # Download from repositogy
  echo "Downloading Energi Core Node and scripts"
  
  cd ${USRHOME}
  # Pull energi from Amazon S3
  wget -4qo- "${S3URL}/${GIT_LATEST}/${ENERGI_EXE}-${GIT_LATEST}-linux-${OSARCH}.tgz" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  
  tar xvfz ${ENERGI_EXE}-${GIT_LATEST}-linux-${OSARCH}.tgz
  sleep 0.3
  
  # Copy latest energi and cleanup
  if [[ -x "${ENERGI_EXE}" ]]
  then
    mv ${ENERGI_EXE}-${GIT_LATEST}-linux-${OSARCH}/bin/${ENERGI_EXE} ${BIN_DIR}/.
    rm -rf ${ENERGI_EXE}-${GIT_LATEST}-linux-${OSARCH}
  else
    mv ${ENERGI_EXE}-${GIT_LATEST}-linux-${OSARCH} ${ENERGI_EXE}
  fi
  rm ${ENERGI_EXE}-${GIT_LATEST}-linux-${OSARCH}.tgz
  
  # Check if software downloaded
  if [ ! -d ${BIN_DIR} ]
  then
    echo "${RED}ERROR: energi-${GIT_LATEST}-linux-${OSARCH}.tgz did not download${NC}"
    sleep 5
  fi
  
  # Check if software downloaded
  if [ ! -d ${BIN_DIR} ]
  then
    echo "${RED}ERROR: energi-${GIT_LATEST}-linux-${OSARCH}.tgz did not download${NC}"
    sleep 5
  fi
  
  # Create missing app directories
  _setup_appdir
  
  
  cd ${BIN_DIR}

  chmod 755 ${ENERGI_EXE}
  if [[ ${EUID} = 0 ]]
  then
    chown ${USRNAME}:${USRNAME} ${ENERGI_EXE}
  fi
  
  # Clean-up
  rm -rf ${ENERGI_HOME}.old
  
  # Change to install directory
  cd
  
}

_version_gt() { 

  # Check if FIRST version is greater than SECOND version
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
  
}

_upgrade_energi () {
  
  # Check the latest version in Github 
  
  GITHUB_LATEST=$( curl -s ${API_URL} )
  GIT_VERSION=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
  
  # Extract latest version number without the 'v'
  GIT_LATEST=$( echo ${GIT_VERSION} | sed 's/v//g' )
  
  # Rename energi3 if 3.1.x and above is released
  if [[ -d ${USRHOME}/energi3 ]]
  then
    if _version_gt ${GIT_LATEST} 3.0.99; then
      mv ${USRHOME}/energi3/bin/energi3 ${USRHOME}/energi3/bin/energi
      mv ${USRHOME}/energi3 ${USRHOME}/energi
      ${SUDO} rm /etc/logrotate.d/energi3
      _add_logrotate
      
      ${SUDO} systemctl disable energi3.service
      ${SUDO} rm /lib/systemd/system/energi3.service
      _add_systemd
      
    else
      ENERGI_EXE=energi3
      ENERGI_HOME=${USRHOME}/energi3
    fi
  fi
  
  # Set PATH to energi
  export BIN_DIR=${ENERGI_HOME}/bin
  
  # Installed Version
  INSTALL_VERSION=$( ${BIN_DIR}/${ENERGI_EXE} version 2>/dev/null | grep "^Version" | awk '{ print $2 }' | awk -F\- '{ print $1 }' )
  
  if _version_gt ${GIT_LATEST} ${INSTALL_VERSION}; then
    echo "Installing newer version ${GIT_VERSION} from Github"
    if [[ -f "${CONF_DIR}/removedb-list.db" ]]
    then
      rm -f ${CONF_DIR}/removedb-list.db
      wget -4qo- "${BASE_URL}/utils/removedb-list.db?dl=1" -O "${CONF_DIR}/removedb-list.db" --show-progress --progress=bar:force:noscroll 2>&1
    else
      wget -4qo- "${BASE_URL}/utils/removedb-list.db?dl=1" -O "${CONF_DIR}/removedb-list.db" --show-progress --progress=bar:force:noscroll 2>&1 
    fi
    
    if [[ $EUID = 0 ]]
    then
      chown ${USRNAME}:${USRNAME} ${CONF_DIR}/removedb-list.db
    fi
    
    _install_energi
    
  else
    echo "Latest version of Energi is installed: ${INSTALL_VERSION}"
    echo "Nothing to install"
    sleep 0.3
  fi

}

_restrict_logins() {

  # Secure server by restricting who can login
  
  # Have linux passwords show stars.
  if [[ -f /etc/sudoers ]] && [[ $( ${SUDO} grep -c 'env_reset,pwfeedback' /etc/sudoers ) -eq 0 ]]
  then
    echo "Show password feeback."
    ${SUDO} cat /etc/sudoers | sed -r 's/^Defaults(\s+)env_reset$/Defaults\1env_reset,pwfeedback/' | ${SUDO} EDITOR='tee ' visudo >/dev/null
    echo "Restarting ssh."
    ${SUDO} systemctl restart sshd
    sleep 0.2
    SSHSTATUS=`${SUDO} systemctl status sshd | grep Active | awk '{print $2}'`
    if [ "${SSHSTATUS}" != "active" ]
    then
      echo "${RED}CRITICAL: sshd did not start correctly. Check configuration file${NC}"
      sleep 1
    fi
  fi

  USRS_THAT_CAN_LOGIN=$( whoami )
  USRS_THAT_CAN_LOGIN="root ${USRNAME} ${USRS_THAT_CAN_LOGIN}"
  USRS_THAT_CAN_LOGIN=$( echo "${USRS_THAT_CAN_LOGIN}" | xargs -n1 | sort -u | xargs )
  ALL_USERS=$( cut -d: -f1 /etc/passwd )

  BOTH_LISTS=$( sort <( echo "${USRS_THAT_CAN_LOGIN}" | tr " " '\n' ) <( echo "${ALL_USERS}" | tr " " '\n' ) | uniq -d | grep -Ev "^$" )
  if [[ $( grep -cE '^AllowUsers' /etc/ssh/sshd_config ) -gt 0 ]]
  then
    USRS_THAT_CAN_LOGIN_2=$( grep -E '^AllowUsers' /etc/ssh/sshd_config | sed -e 's/^AllowUsers //g' )
    BOTH_LISTS=$( echo ${USRS_THAT_CAN_LOGIN_2} ${BOTH_LISTS} | xargs -n1 | sort -u | xargs )
    MISSING_FROM_LISTS=$( join -v 2 <(sort <( echo "${USRS_THAT_CAN_LOGIN_2}" | tr " " '\n' ))  <(sort <( echo "${BOTH_LISTS}" | tr " " '\n' ) ))
  else
    MISSING_FROM_LISTS=${BOTH_LISTS}
  fi
  if [[ -z "${BOTH_LISTS}" ]]
  then
    echo "User login can not be restricted."
    return
  fi
  if [[ -z "${MISSING_FROM_LISTS}" ]]
  then
    # Do nothing if no users are missing.
    return
  fi
  echo
  echo ${BOTH_LISTS}
  REPLY='y'
#  read -p "Make it so only the above list of users can login via SSH ([y]/n)?: " -r
#  REPLY=${REPLY,,} # tolower
  echo "Only the above list of users can login via SSH"
  sleep 0.3
  if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
  then
    if [[ $( grep -cE '^AllowUsers' /etc/ssh/sshd_config ) -eq 0 ]]
    then
      ${SUDO} echo "AllowUsers "${BOTH_LISTS} >> /etc/ssh/sshd_config
    else
      ${SUDO} sed -ie "/AllowUsers/ s/$/ ${MISSING_FROM_LISTS} /" /etc/ssh/sshd_config
    fi
    USRS_THAT_CAN_LOGIN=$( grep -E '^AllowUsers' /etc/ssh/sshd_config | sed -e 's/^AllowUsers //g' | tr " " '\n' )
    echo "Restarting ssh."
    ${SUDO} systemctl restart sshd
    sleep 0.2
    SSHSTATUS=`${SUDO} systemctl status sshd | grep Active | awk '{print $2}'`
    if [ "${SSHSTATUS}" != "active" ]
    then
      echo "${RED}CRITICAL: sshd did not start correctly. Check configuration file${NC}"
      sleep 1
    fi
    echo "List of users that can login via SSH (/etc/ssh/sshd_config):"
    echo ${USRS_THAT_CAN_LOGIN}
  fi
  
}

_secure_host() {

  # Enable Local Firewall
  if [[ ! -x "$( command -v ufw )" ]]
  then
    echo "Installing missing package to secure server"
    ${SUDO} apt-get install -yq ufw 2:/dev/null
  fi
  
  echo "Limiting secure shell (ssh) to access servers and RPC port ${FWPORT} to access Energi3 Node"
  ${SUDO} ufw allow ssh/tcp
  ${SUDO} ufw limit ssh/tcp
  if [ ! -z "${FWPORT}" ]
  then
    ${SUDO} ufw allow ${FWPORT}/tcp
    ${SUDO} ufw allow ${FWPORT}/udp
  fi
  ${SUDO} ufw logging on
  ${SUDO} ufw --force enable
  
}

_setup_two_factor() {

  ${SUDO} service apache2 stop 2>/dev/null
  ${SUDO} update-rc.d apache2 disable 2>/dev/null
  ${SUDO} update-rc.d apache2 remove 2>/dev/null

  # Ask to review if .google_authenticator file already exists.
  if [[ -s "${USRHOME}/.google_authenticator" ]]
  then
    REPLY=''
    read -p "Review 2 factor authentication code for password SSH login (y/[n])?: " -r
    REPLY=${REPLY,,} # tolower
    if [[ "${REPLY}" == 'n' ]] || [[ -z "${REPLY}" ]]
    then
      return
    fi
  fi

  # Clear out an old failed run.
  if [[ -f "${USRHOME}/.google_authenticator.temp" ]]
  then
    rm "${USRHOME}/.google_authenticator.temp"
  fi

  # Install google-authenticator if not there.
  NEW_PACKAGES=''
  if [ ! -x "$( command -v google-authenticator )" ]
  then
    NEW_PACKAGES="${NEW_PACKAGES} libpam-google-authenticator"
  fi
  if [ ! -x "$( command -v php )" ]
  then
    NEW_PACKAGES="${NEW_PACKAGES} php-cli"
  fi
  if [ ! -x "$( command -v qrencode )" ]
  then
    NEW_PACKAGES="${NEW_PACKAGES} qrencode"
  fi
  if [[ ! -z "${NEW_PACKAGES}" ]]
  then
    echo "Installing ${NEW_PACKAGES}"
    ${SUDO} apt-get install -yq ${NEW_PACKAGES} 2>/dev/null

    ${SUDO} service apache2 stop 2>/dev/null
    ${SUDO} update-rc.d apache2 disable 2>/dev/null
    ${SUDO} update-rc.d apache2 remove 2>/dev/null
  fi

  if [[ ! -f "${ETC_DIR}/otp.php" ]]
  then
    cd ${ETC_DIR}
    echo "${TP_URL}/otp.php"
    wget -4qo- ${TP_URL}/otp.php -O "${ETC_DIR}/otp.php" --show-progress --progress=bar:force:noscroll 2>&1
    chmod 644 "${ETC_DIR}/otp.php"
    cd -
  fi
  
  if [[ ${EUID} = 0 ]]
  then
    chown ${USRNAME}:${USRNAME} "${ETC_DIR}/otp.php"
  fi

  # Generate otp.
  IP_ADDRESS=$( timeout --signal=SIGKILL 10s curl -s http://ipinfo.io/ip )
  SECRET=''
  if [[ -f "${USRHOME}/.google_authenticator" ]]
  then
    SECRET=$( ${SUDO} head -n 1 "${USRHOME}/.google_authenticator" 2>/dev/null )
  fi
  if [[ -z "${SECRET}" ]]
  then
    if [[ ${EUID} = 0 ]]
    then
      su - ${USRNAME} -c 'google-authenticator -t -d -f -r 10 -R 30 -w 5 -q -Q UTF8 -l "ssh login for '${USRNAME}'"'
    else
      google-authenticator -t -d -f -r 10 -R 30 -w 5 -q -Q UTF8 -l "ssh login for '${USRNAME}'"
    fi  
    # Add 5 recovery digits.
    {
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    } | ${SUDO} tee -a  "${USRHOME}/.google_authenticator" >/dev/null
    SECRET=$( ${SUDO} head -n 1 "${USRHOME}/.google_authenticator" 2>/dev/null )
  fi
  
  if [[ -z "${SECRET}" ]]
  then
    echo "Google Authenticator install failed."
    return
  fi
  
  if [[ -f "${USRHOME}/.google_authenticator" ]]
  then
    mv "${USRHOME}/.google_authenticator" "${USRHOME}/.google_authenticator.temp"
    CHMOD_G_AUTH=$( stat --format '%a' ${USRHOME}/.google_authenticator.temp )
    chmod 666 "${USRHOME}/.google_authenticator.temp"
  else
    CHMOD_G_AUTH=400
  fi
  clear

  stty sane 2>/dev/null
  echo "Warning: pasting the following URL into your browser exposes the OTP secret to Google:"
  echo "https://www.google.com/chart?chs=200x200&chld=M|0&cht=qr&chl=otpauth://totp/ssh%2520login%2520for%2520'${USRNAME}'%3Fsecret%3D${SECRET}%26issuer%3D${IP_ADDRESS}"
  echo
  
  stty sane 2>/dev/null
  qrencode -l L -m 2 -t UTF8 "otpauth://totp/ssh%20login%20for%20'${USRNAME}'?secret=${SECRET}&issuer=${IP_ADDRESS}"
  stty sane 2>/dev/null
  
  echo "Scan the QR code with the Google Authenticator app; or manually enter"
  echo "Account: ${USRNAME}@${IP_ADDRESS}"
  echo "Key: ${SECRET}"
  echo "This is a time based code"
  echo "When logging into this VPS via password, a 6 digit code would also be required."
  echo "If you loose this code you can still use your wallet on your desktop."
  echo
  
  # Validate otp.
  while :
  do
    REPLY=''
    read -p "6 digit verification code (leave blank to disable & delete): " -r
    if [[ -z "${REPLY}" ]]
    then
      rm -f "${USRHOME}/.google_authenticator"
      rm -f "${USRHOME}/.google_authenticator.temp"
      echo "Not going to use google authenticator."
      return
    fi

    KEY_CHECK=$( php "${ETC_DIR}/otp.php" "${REPLY}" "${USRHOME}/.google_authenticator.temp" )
    if [[ ! -z "${KEY_CHECK}" ]]
    then
      echo "${KEY_CHECK}"
      if [[ $( echo "${KEY_CHECK}" | grep -ic 'Key Verified' ) -gt 0 ]]
      then
        break
      fi
    fi
  done

  if [[ -f "${USRHOME}/.google_authenticator.temp" ]]
  then
    chmod "${CHMOD_G_AUTH}" "${USRHOME}/.google_authenticator.temp"
    if [[ ${EUID} = 0 ]]
    then
      chown ${USRNAME}:${USRNAME} "${USRHOME}/.google_authenticator.temp"
    fi
    mv "${USRHOME}/.google_authenticator.temp" "${USRHOME}/.google_authenticator"
  fi

  echo "Your emergency scratch codes are (write these down in a safe place):"
  grep -oE "[0-9]{8}" "${USRHOME}/.google_authenticator" | awk '{print "  " $1 }'

  read -r -p $'Use this 2 factor code \e[7m(y/n)\e[0m? ' -e 2>&1
  REPLY=${REPLY,,} # tolower
  if [[ "${REPLY}" == 'y' ]]
  then
    if [[ $( grep -c 'auth required pam_google_authenticator.so nullok' /etc/pam.d/sshd ) -eq 0 ]]
    then
      echo "auth required pam_google_authenticator.so nullok" | ${SUDO} tee -a "/etc/pam.d/sshd" >/dev/null
    fi
    ${SUDO} sed -ie 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
    ${SUDO} systemctl restart sshd.service
    echo
    echo "If using Bitvise select keyboard-interactive with no submethods selected."
    echo

    # Allow for 20 bad root login attempts before killing the ip.
    if [[ -f /etc/denyhosts.conf ]]
    then
      ${SUDO} sed -ie 's/DENY_THRESHOLD_ROOT \= 1/DENY_THRESHOLD_ROOT = 5/g' /etc/denyhosts.conf
      ${SUDO} sed -ie 's/DENY_THRESHOLD_RESTRICTED \= 1/DENY_THRESHOLD_RESTRICTED = 5/g' /etc/denyhosts.conf
      ${SUDO} sed -ie 's/DENY_THRESHOLD_ROOT \= 1/DENY_THRESHOLD_ROOT = 20/g' /etc/denyhosts.conf
      ${SUDO} sed -ie 's/DENY_THRESHOLD_RESTRICTED \= 1/DENY_THRESHOLD_RESTRICTED = 20/g' /etc/denyhosts.conf
      ${SUDO} systemctl restart denyhosts
    fi
    sleep 5
    clear
  else
    rm -f "${USRHOME}/.google_authenticator"
  fi

}

_add_rsa_key() {
  while :
  do
    TEMP_RSA_FILE=$( mktemp )
    printf "Enter the PUBLIC ssh key (starts with ssh-rsa AAAA) and press [ENTER]:\n\n"
    read -r SSH_RSA_PUBKEY
    if [[ "${#SSH_RSA_PUBKEY}" -lt 10 ]]
    then
      echo "Quiting without adding rsa key."
      echo
      break
    fi
    echo "${SSH_RSA_PUBKEY}" >> "${TEMP_RSA_FILE}"
    SSH_TEST=$( ssh-keygen -l -f "${TEMP_RSA_FILE}"  2>/dev/null )
    if [[ "${#SSH_TEST}" -gt 10 ]]
    then
      if [[ ! -d "${USRHOME}/.ssh" ]]
      then
        mkdir -p "${USRHOME}/.ssh"
      fi
      touch "${USRHOME}/.ssh/authorized_keys"
      chmod 644 "${USRHOME}/.ssh/authorized_keys"
      echo "${SSH_RSA_PUBKEY}" >> "${USRHOME}/.ssh/authorized_keys"
      if [[ ${EUID} = 0 ]]
      then
        chown -R ${USRNAME}:${USRNAME} "${USRHOME}/.ssh"
      fi
      echo "Added ${SSH_TEST}"
      echo
      break
    fi

    rm -rf "${TEMP_RSA_FILE}"
  done
}

_check_clock() {
  if [ ! -x "$( command -v ntpdate )" ]
  then
    echo "Installing ntpdate"
    ${SUDO} apt-get install -yq ntpdate 2>/dev/null
  fi
  echo "Checking system clock..."
  ${SUDO} ntpdate -q pool.ntp.org | tail -n 1 | grep -o 'offset.*' | awk '{print $1 ": " $2 " " $3 }' 2>/dev/null
}

_add_swap () {
  # Add 2GB additional swap
  if [ ! -f /var/swapfile ]
  then
    echo "Adding additional swap"
    ${SUDO} fallocate -l 2G /var/swapfile
    ${SUDO} chmod 600 /var/swapfile
    ${SUDO} mkswap /var/swapfile
    ${SUDO} swapon /var/swapfile

    ${SUDO} echo -e "/var/swapfile\t none\t swap\t sw\t 0\t 0" >> /etc/fstab
    echo "Added 2GB swap space to the server"
  else
    echo "Swap already exists. No additional swap space added."
  fi
}

_copy_keystore() {

  # Copy Energi3 keystore file to computer

  # Download ffsend if needed
    # Install ffsend and jq as well.
  if [ ! -x "$( command -v snap )" ] || [ ! -x "$( command -v jq )" ] || [ ! -x "$( command -v column )" ]
  then
    echo "Installing snap, snapd, bsdmainutils"
    ${SUDO} apt-get install -yq snap 2>/dev/null
    ${SUDO} apt-get install -yq snapd 2>/dev/null
    ${SUDO} apt-get install -yq jq bsdmainutils 2>/dev/null
  fi
  if [ ! -x "$( command -v ffsend )" ]
  then
    ${SUDO} snap install ffsend
  fi

  if [ ! -x "$( command -v ffsend )" ]
  then
    FFSEND_URL=$( wget -4qO- -o- https://api.github.com/repos/timvisee/ffsend/releases/latest | jq -r '.assets[].browser_download_url' | grep static | grep linux )
    cd "${ENERGI_HOME}/bin/"
    wget -4q -o- "${FFSEND_URL}" -O "ffsend"
    chmod 755 "ffsend"
    cd -
  fi
  
  clear
  echo
  echo "Next we will copy the keystore file from your desktop to the VPS."
  echo "To start click on link below:"
  echo
  echo "https://send.firefox.com/"
  echo
  echo "Once upload completes, copy the URL from Firefox and paste below:"
  sleep .3
  echo
  REPLY=''
  while [[ -z "${REPLY}" ]] || [[ "$( echo "${REPLY}" | grep -c 'https://send.firefox.com/download/' )" -eq 0 ]]
  do
    read -p "Paste URL (leave blank and hit ENTER to do it manually): " -r
    if [[ -z "${REPLY}" ]]
    then      
      echo "Please copy the keystore file to ${CONF_DIR}/keystore directory on your own using"
      echo "an sftp software WSFTP or "
      read -p "Press Enter Once Done: " -r
      if [[ ${EUID} = 0 ]]
      then
        chown -R "${USRNAME}":"${USRNAME}" "${CONF_DIR}"
      fi
      chmod 600 "${CONF_DIR}/keystore/UTC*"
    fi
  done

  while :
  do
    TEMP_DIR_NAME=$( mktemp -d -p "${USRHOME}" )
    if [[ -z "${REPLY}" ]]
    then
      read -p "URL (leave blank to skip): " -r
      if [[ -z "${REPLY}" ]]
      then
        break
      fi
    fi

    # Trim white space.
    REPLY=$( echo "${REPLY}" | xargs )
    if [[ -f "${ENERGI_HOME}/bin/ffsend" ]]
    then
      "${ENERGI_HOME}/bin/ffsend" download -y --verbose "${REPLY}" -o "${TEMP_DIR_NAME}/"
    else
      ffsend download -y --verbose "${REPLY}" -o "${TEMP_DIR_NAME}/"
    fi

    KEYSTOREFILE=$( find "${TEMP_DIR_NAME}/" -type f )
    BASENAME=$( basename "${KEYSTOREFILE}" )
    ACCTNUM="0x`echo ${BASENAME} | awk -F\-\- '{ print $3 }'`"
    if [[ -z "${KEYSTOREFILE}" ]]
    then
      echo "Download failed; try again."
      REPLY=''
      continue
    fi
    
    if [ -d ${CONF_DIR}/keystore ]
    then
      KEYSTORE_EXIST=`find ${CONF_DIR}/keystore -name ${BASENAME} -print`
    else
      mkdir -p ${CONF_DIR}/keystore
      chmod 700 ${CONF_DIR}/keystore
      if [[ ${EUID} = 0 ]]
      then
        chown -R "${USRNAME}":"${USRNAME}" "${CONF_DIR}"
      fi
      KEYSTORE_EXIST=''
    fi
    
    if [[ ! -z "${KEYSTORE_EXIST}" ]]
    then
      echo "Backing up ${BASENAME} file"
      mkdir -p ${ENERGI_HOME}/backups
      mv "${CONF_DIR}/keystore/${BASENAME}" "${ENERGI_HOME}/backups/${BASENAME}.bak"
      if [[ ${EUID} = 0 ]]
      then      
        chown "${USRNAME}":"${USRNAME}" ${ENERGI_HOME}/backups
      fi
    fi
    
    #
    mv "${KEYSTOREFILE}" "${CONF_DIR}/keystore/${BASENAME}"   
    chmod 600 "${CONF_DIR}/keystore/${BASENAME}"
    if [[ ${EUID} = 0 ]]
    then
      chown "${USRNAME}":"${USRNAME}" "${CONF_DIR}/keystore/${BASENAME}"
    fi
    
    echo "Keystore Account ${ACCTNUM} copied to:"
    echo "${CONF_DIR}/keystore on VPS"
    
    # Remove temp directory
    rm -rf "${TEMP_DIR_NAME}"
    REPLY=''

  done

}

_download_bootstrap () {
  
  # Download latest bootstrap and extract it
  echo "Downloading latest bootstrap..."
  wget -4qo- "${BOOTSTRAP_URL}?dl=1" -O "${USRHOME}/gen3-bootstrap.tar.gz" --show-progress --progress=bar:force:noscroll 2>&1
  
  if [[ -f ${USRHOME}/gen3-bootstrap.tar.gz ]]
  
    cd ${USRHOME}
    echo "Extracting bootstrap file..."
    tar xvfz gen3-bootstrap.tar.gz
    
    if [[ ${EUID} = 0 ]]
    then
      chown -R "${USRNAME}":"${USRNAME}" ${CONF_DIR}
    fi
    rm -rf ${USRHOME}/gen3-bootstrap.tar.gz
    
  fi

}

_start_energi () {

  # Start energi
  
  SYSTEMCTLSTATUS=`systemctl status energi.service | grep "Active:" | awk '{print $2}'`
  if [[ "${SYSTEMCTLSTATUS}" != "Active" ]]
  then
    echo "Starting Energi Core Node...."
    ${SUDO} systemctl start energi.service
  else
    echo "energi service is running..."
  fi

}

_stop_energi () {

  # Check if energi process is running and stop it
  
  SYSTEMCTLSTATUS=`systemctl status energi.service | grep "Active:" | awk '{print $2}'`
  
  if [[ "${SYSTEMCTLSTATUS}" = "active" ]]
  then
    echo "Stopping Energi Core Node..."
    ${SUDO} systemctl stop energi.service
    sleep 1
  else
    echo "energi service is not running..."
  fi
  
}

_get_enode () {

  # Print enode of core node
  I=1
  while [ ! -S ${CONF_DIR}/energi3.ipc ] || [ ${I} = 60 ]
  do
    sleep 1
    ((I++))
  done
  sleep 1
  
  if [[ ${EUID} = 0 ]] && [[ -S ${CONF_DIR}/energi3.ipc ]]
  then
    echo "${GREEN}To Announce Masternode go to:${NC} https://gen3.energi.network/masternodes/announce"
    echo -n "Owner Address: "
    su - ${USRNAME} -c "${BIN_DIR}/energi ${APPARG} attach -exec 'personal.listAccounts' " 2>/dev/null | jq -r '.[]' | head -1
    echo "Masternode enode URL: "
    su - ${USRNAME} -c "${BIN_DIR}/energi ${APPARG} attach -exec 'admin.nodeInfo.enode' " 2>/dev/null | jq -r
  else
    echo "${GREEN}To Announce Masternode go to:${NC} https://gen3.energi.network/masternodes/announce"
    echo -n "Owner Address: "
    energi ${APPARG} attach -exec "personal.listAccounts" 2>/dev/null | jq -r | head -1
    echo "Masternode enode URL: "
    energi ${APPARG} attach -exec "admin.nodeInfo.enode" 2>/dev/null | jq -r
  fi
  echo

}


_stop_nodemon () {
  
  # Check if nodemon is running. If so, stop and remove
  if [ -f /etc/systemd/system/nodemon.service ]
  then
    echo "Stopping nodemon service for Energi"
    ${SUDO} systemctl stop nodemon.timer
    ${SUDO} systemctl disable nodemon.timer
  fi
  
  if [ -f /etc/systemd/system/nodemon.service ]
  then
    echo "Saving nodemon.service"
    mv /etc/systemd/system/nodemon.service ${USRHOME}/.
  fi

  if [ -f /etc/systemd/system/nodemon.slice ]
  then
    echo "Saving nodemon.slice"
    mv /etc/systemd/system/nodemon.slice ${USRHOME}/.
  fi
  
  if [ -f /etc/systemd/system/nodemon.timer ]
  then
    echo "Saving nodemon.timer"
    mv /etc/systemd/system/nodemon.timer ${USRHOME}/.
  fi
  
}


_ascii_logo () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_
 /:/ /:/ /\__\  ______ _   _ ______ _____   _____ _____ ____  
 \:\ \/ /:/  / |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
  \:\  /:/  /  | |__  |  \| | |__  | |__) | |  __  | |   __) |
   \:\/:/  /   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
    \::/  /    | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
     \/__/     |______|_| \_|______|_|  \_\\_____|_____|____/ 
ENERGI
echo -n ${NC}
}

_ascii_logo_bottom () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_
 /:/ /:/ /\__\  ______ _   _ ______ _____   _____ _____ ____  
 \:\ \/ /:/  / |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
  \:\  /:/  /  | |__  |  \| | |__  | |__) | |  __  | |   __) |
   \:\/:/  /   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
    \::/  /    | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
     \/__/     |______|_| \_|______|_|  \_\\_____|_____|____/ 
ENERGI
echo -n ${NC}
}

_ascii_logo_2 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \
   /:/\:\__\
  /:/ /:/ _/_   ______ _   _ ______ _____   _____ _____ ____  
 /:/ /:/ /\__\ |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
 \:\ \/ /:/  / | |__  |  \| | |__  | |__) | |  __  | |   __) |
  \:\  /:/  /  |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
   \:\/:/  /   | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
    \::/  /    |______|_| \_|______|_|  \_\\_____|_____|____/ 
     \/__/     
ENERGI
echo -n ${NC}
}

_ascii_logo_3 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \
   /:/\:\__\    ______ _   _ ______ _____   _____ _____ ____  
  /:/ /:/ _/_  |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
 /:/ /:/ /\__\ | |__  |  \| | |__  | |__) | |  __  | |   __) |
 \:\ \/ /:/  / |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
  \:\  /:/  /  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
   \:\/:/  /   |______|_| \_|______|_|  \_\\_____|_____|____/ 
    \::/  /    
     \/__/     
ENERGI
echo -n ${NC}
}

_ascii_logo_4 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \
    /::\  \     ______ _   _ ______ _____   _____ _____ ____  
   /:/\:\__\   |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
  /:/ /:/ _/_  | |__  |  \| | |__  | |__) | |  __  | |   __) |
 /:/ /:/ /\__\ |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
 \:\ \/ /:/  / | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
  \:\  /:/  /  |______|_| \_|______|_|  \_\\_____|_____|____/ 
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI
echo -n ${NC}
}

_ascii_logo_5 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___
     /\  \      ______ _   _ ______ _____   _____ _____ ____  
    /::\  \    |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
   /:/\:\__\   | |__  |  \| | |__  | |__) | |  __  | |   __) |
  /:/ /:/ _/_  |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
 /:/ /:/ /\__\ | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 \:\ \/ /:/  / |______|_| \_|______|_|  \_\\_____|_____|____/ 
  \:\  /:/  /  
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI
echo -n ${NC}
}

_ascii_logo_top () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ ____  
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \ 
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ < 
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/ 
 \:\ \/ /:/  / 
  \:\  /:/  /  
   \:\/:/  /   
    \::/  /    
     \/__/     
ENERGI
echo -n ${NC}
}

_menu_option_new () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) New server installation of Energi3"
echo "${GREEN}    \::/  /    ${NC}"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

_menu_option_mig () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) Upgrade Energi v2 to v3; automatic wallet migration"
echo "${GREEN}    \::/  /    ${NC}   b) Upgrade Energi v2 to v3; manual wallet migration"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

_menu_option_upgrade () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) Upgrade version of Energi3"
echo "${GREEN}    \::/  /    ${NC}"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

_welcome_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Welcome to the Energi3 Installer."
echo "${GREEN}   \:\/:/  /   ${NC}- New Install : No previous installs"
echo "${GREEN}    \::/  /    ${NC}- Upgrade     : Upgrade previous version"
echo "${GREEN}     \/__/ "
echo ${NC}
read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."
}

_end_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI
echo "${GREEN}  \:\  /:/  /  ${NC}Please logout and log back in as ${USRNAME}"
echo "${GREEN}   \:\/:/  /   ${NC}To start energi: sudo systemctl start energi"
echo "${GREEN}    \::/  /    ${NC}To stop energi : sudo systemctl stop energi"
echo "${GREEN}     \/__/     ${NC}For status      : sudo systemctl status energi"
echo ${NC}"For instructions visit: ${DOC_URL}"
echo
}


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Main Program
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

# Make installer interactive and select normal mode by default.
isMainnet="y"
INTERACTIVE="y"
BOOTSTRAP="n"
POSITIONAL=()

while [[ $# -gt 0 ]]
do
  key="$1"
  shift

  case $key in
    -b|--bootstrap)
        BOOTSTRAP="y"
        ;;
    -n|--no-interaction)
        INTERACTIVE="n"
        ;;
    -t|--testnet|-testnet)
        isMainnet="n"
        ;;
    -r|--rsa)
    
        ;;
    -f|--2fa)
    
        ;;
    -d|--debug)
        set -x
        ;;
    -h|--help)
        cat << EOL

Energi installer arguments:
    -b --bootstrap            : Sync node using Bootstrap
    -n --no-interaction       : No interaction mode
    -t --testnet              : Setup testnet
    -r --rsa                  : Setup token based login
    -f --2fa                  : Setup 2-Factor Authentication
    -h --help                 : Display this help text
    -d --debug                : Debug mode

EOL
        exit
        ;;
    *)
        $0 -h
        ;;
  esac
done


#
# Clears screen and present Energi3 logo
_ascii_logo_bottom
sleep 0.2
_ascii_logo_2
sleep 0.2
_ascii_logo_3
sleep 0.2
_ascii_logo_4
sleep 0.2
_ascii_logo_5
sleep 0.2
_welcome_instructions

# Check architecture
_os_arch

# Check Install type and set ENERGI_HOME
_check_install
#read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."

# Present menu to choose an option based on Installation Type determined
case ${INSTALLTYPE} in
  new)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Scenario:
    #   * No energi3.ipc file on the computer
    #   * No energi.conf file on the computer
    #
    # Menu Options
    #   a) New server installation of Energi3
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    _menu_option_new
    
    REPLY='x'
    read -p "Please select an option to get started (a or x): " -r
    REPLY=${REPLY,,} # tolower
    if [ "${REPLY}" = "" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # New server installation of Energi3
        
        # ==> Run as root / sudo <==
        _install_apt
        _restrict_logins
        _set_ismainnet
        _secure_host
        _check_clock
        _add_swap
        _add_logrotate
        
        # Check if user wants to install 2FA
        clear 2> /dev/null
        echo "2-Factor Authentication (2FA) require you to enter a 6 digit one-time password"
        echo "(OTP) after you login to the server. You need to install ${GREEN}Google Authenticator${NC}"
        echo "on your mobile to enable the 2FA. The OTP changes every 60 sec. This will secure"
        echo "your server and restrict who can login."
        echo
        
        REPLY=''
        read -p "Do you want to install 2-Factor Authentication [Y/n]?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
        then
          _setup_two_factor
        fi

        _install_energi
        _download_bootstrap
        
        REPLY=''
        read -p "Do you want to copy the keystore file to the VPS (y/[n])?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]]
        then
          _copy_keystore
        else
          if [ -d ${CONF_DIR}/keystore ]
          then
            mkdir -p ${CONF_DIR}/keystore
            chmod 700 ${CONF_DIR}/keystore
            if [[ ${EUID} = 0 ]]
            then
              chown -R "${USRNAME}":"${USRNAME}" "${CONF_DIR}"
            fi
          fi
        fi

        _add_systemd
        
        _start_energi
        
        ;;
        
      x)
        # Exit - Nothing to do
        echo
        echo
        echo "Nothing to install.  Exiting from the installer."
        exit 0
    
        ;;
  
      h)
        echo
        echo
        echo "${RED}ERROR: ${NC}Need to select one of the options to continue..."
        echo
        echo "Restart the installer"
        exit 0
        ;;

    esac
      
    ;;
  
  upgrade)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Scenario:
    #   * energi3.ipc file exists
    #   * Keystore file exists
    #   * Version on computer is older than version in Github
    #
    # Menu Options
    #   a) Upgrade version of Energi3
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    _menu_option_upgrade
    
    REPLY='x'
    read -p "Please select an option to get started (a or x): " -r
    REPLY=${REPLY,,} # tolower
    
    if [ "x${REPLY}" = "x" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # Upgrade version of Energi3
        _stop_energi
        _install_apt
        _restrict_logins
        _set_ismainnet
        _secure_host
        _check_clock
        _add_swap
        _upgrade_energi
        _add_logrotate
        
        if [[ -f ${CONF_DIR}/removedb-list.db ]]
        then
          for L in `cat ${CONF_DIR}/removedb-list.db`
          do
            if [[ ${L} = ${INSTALL_VERSION} ]]
            then
              echo "${GREEN}Vesion ${L} requires a reset of chaindata${NC}"
              ${BIN_DIR}/${ENERGI_EXE} removedb
              _download_bootstrap
              break
              
              if [[ -f "${CONF_DIR}/energi/chaindata/CURRENT" ]]
              then
                echo "Removing chaindata..."
                rm -rf ${CONF_DIR}/energi/chaindata/*
                _download_bootstrap
              fi
              
            fi
          done
        fi
        
        _start_energi
 
        ;;
      
      b)
        # Install monitoring on Discord and/or Telegram
        echo "Monitoring functionality to be added"
        ;;
        
      x)
        # Exit - Nothing to do
        echo
        echo
        echo "Nothing to install.  Exiting from the installer."
        exit 0
        ;;
  
      h)
        echo
        echo
        echo "${RED}ERROR: ${NC}Need to select one of the options to continue..."
        echo
        echo "Restart the installer"
        exit 0
        ;;
        
    esac
    ;;

esac

##
# End installer
##
_end_instructions

# present enode information
_get_enode


# End of Installer
