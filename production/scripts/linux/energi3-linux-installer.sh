#!/bin/bash

#####################################################################
# Copyright (c) 2020
# All rights reserved.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# Desc:   Batch script to download and setup Energi 3.x on Linux. The
#         script will upgrade an existing installation.
# 
# Version:1.0 ZA Initial Script
#
: '
# Run the script to get started:
```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/energicryptocurrency/energi3/master/scripts/linux/energi3-linux-installer.sh)" ; source ~/.bashrc
```
'
#####################################################################


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Global Variables
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

# Check if we have enough memory
if [[ $(free -m | awk '/^Mem:/{print $2}') -lt 850 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# OS Settings
export DEBIAN_FRONTEND=noninteractive 

# Locations of Repositories and Guide
API_URL='https://api.github.com/repos/energicryptocurrency/energi3/releases/latest'
SCRIPT_URL='https://raw.githubusercontent.com/energicryptocurrency/energi3/master/scripts/linux'
DOC_URL='https://energi.gitbook.io'
#GITURL=https://raw.githubusercontent.com/energicryptocurrency/energi3

# Energi v3 Bootstrap Settings
#export BLK_HASH=gsaqiry3h1ho3nh
#export BOOTSTRAP_URL="https://www.dropbox.com/s/%BLK_HASH%/energi3bootstrap.tar.gz"

# Snapshot Block (need to update)
MAINNETSSBLOCK=1500000
TESTNETSSBLOCK=1500000

# Set Executables & Configuration
export ENERGI3_EXE=energi3
export ENERGI3_CONF=energi3.toml
export ENERGI3_IPC=energi3.ipc

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
  else
    echo "${RED}not supported${NC}"
    exit 0
  fi
  
  echo -n "OS architecture "
  OSARCH=`uname -m`
  if [ "${OSARCH}" != "x86_64" ]
  then
    echo "${RED}${OSARCH} is not supported${NC}"
    echo "Please goto our website to check which platforms are supported."
    exit 0
  else
    echo "${GREEN}${OSARCH} is supported${NC}"
    sleep 0.3
  fi
  
}

_check_runas () {

  # Who is running the script
  # If root no sudo required
  # If user has sudo privilidges, run sudo when necessary
  #
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
  
  #Check if user nrgstaker exists if not add the user
  CHKPASSWD=`grep ${USRNAME} /etc/passwd`
  
  if [ "${CHKPASSWD}" == "" ]
  then
    echo "You can select the computer to generate a ramdom password and let you know what"
    echo "that is. Or you can select one for yourself that someone can easily guess."
    REPLY=''
    read -p "Do you want to select your own password [y]/n: "
    REPLY=${REPLY,,} # tolower
    if [[ "${REPLY}" == "y" ]] || [[ -z "${REPLY}" ]]
    then
      echo "You will be prompted to enter a secure password"
      echo
      ${SUDO} adduser --gecos "Energi Staking Account" --quiet ${USRNAME}
      
    else
      if [ ! -x "$( command -v  pwgen )" ]
      then
        echo "Installing missing package to generate random password"
        ${SUDO} apt-get install -yq pwgen
      fi
      
      USRPASSWD=`pwgen 8 1`
      echo
      echo "Write down the following before continuing:"
      echo "  Username: ${BLUE}${USRNAME}${NC}"
      echo "  Password: ${BLUE}${USRPASSWD}${NC}"
      echo
      REPLY=''
      read -n 1 -p "Did you write down the username and password? y/[n]: "
      REPLY=${REPLY,,} # tolower
      if [[ "${REPLY}" == "n" ]] || [[ -z "${REPLY}" ]]
      then
        echo "Please write down the username and password before continuing"
        echo "Exiting script!"
        exit 0
      fi
      
      ${SUDO} adduser --gecos "Energi Staking Account" --disabled-password --quiet ${USRNAME}
      echo -e "${USRPASSWD}\n${USRPASSWD}" | ${SUDO} passwd ${USRNAME} 2>/dev/null
        
    fi

    ${SUDO} usermod -aG sudo ${USRNAME}
    ${SUDO} touch /home/${USRNAME}/.sudo_as_admin_successful
    ${SUDO} chown ${USRNAME}:${USRNAME} /home/${USRNAME}/.sudo_as_admin_successful
    ${SUDO} chmod 644 /home/${USRNAME}/.sudo_as_admin_successful
    echo
    echo "${GREEN}*** User ${USRNAME} created and added to sudoer group                       ***${NC}"
    echo "${GREEN}*** User ${USRNAME} will be used to install the software and configurations ***${NC}"
    sleep 3
    
  fi
  
}

_check_install () {

  # Check if run as root or user has sudo privilidges
  _check_runas
  
  CHKV3USRTMP=/tmp/chk_v3_usr.tmp
  ${SUDO} find /home -name energi3.ipc | awk -F\/ '{print $3}' > ${CHKV3USRTMP}
  ${SUDO} find /root -name energi3.ipc | awk -F\/ '{print $3}' >> ${CHKV3USRTMP}
  V3USRCOUNT=`wc -l ${CHKV3USRTMP} | awk '{ print $1 }'`
  
  case ${V3USRCOUNT} in
  
    0)
      #
      # New Installation:
      #   * No energi3.ipc file on the computer
      #   * No energi.conf or energid on the computer
      #
      # Migration Installation:
      #   * energi.conf and energid exists
      #   * No energi3.ipc file on the computer
      #   * energi3.ipc file exists on the computer
      #   * Keystore file does not exists
      #   * No $ENERGI3_HOME/etc/migrated_to_v3.log exists
      #
      echo -n "Checking if Energi v2 is installed: "
      CHKV2USRTMP=/tmp/chk_v2_usr.tmp
      ${SUDO} find /home -name energi.conf | awk -F\/ '{print $3}' > ${CHKV2USRTMP}
      ${SUDO} find /root -name energi.conf | awk -F\/ '{print $3}' >> ${CHKV2USRTMP}
      V2USRCOUNT=`wc -l ${CHKV2USRTMP} | awk '{ print $1 }'`
      
      case ${V2USRCOUNT} in
        0)
          # Energi v2 not installed
          echo "${YELLOW}Not installed${NC}"
          echo

          # Set username
          USRNAME=nrgstaker
          INSTALLTYPE=new
          
          _add_nrgstaker
          
          export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
          export ENERGI3_HOME=${USRHOME}/energi3
          
          ;;
        
        *)
          # Energi v2 is installed
          #
          # User has option to do a fresh install or migrate
          #
          echo "${GREEN}Installed${NC}"
          echo
          echo "You have two options to install Energi v3:"
          echo "  1) Use the same user as used in Energi v2"
          echo "  2) Create a separate installation with a new installation"
          echo
          echo "For both options you can choose to manually migrate the wallet or automatically"
          echo "migrate all funds from Energi v2 to Energi v3."
          echo
          
          isMigrate=""
          read -p "Do you want to migrate from Energi v2 to v3 (y/[n]): "
          isMigrate=${isMigrate,,}    # tolower
          
          if [ "${isMigrate}" = "y" ]
          then
            # If there is multiple user accounts with energi.conf have user choose one
            I=1
            for U in `cat ${CHKV2USRTMP}`
            do
              # Create an array of USR and present for selection
              USR[${I}]=${U}
              echo "${I}: ${USR[${I}]}"
              ((I=I+1))
              if [ ${I} = ${V2USRCOUNT} ]
              then
                break
              fi
            done
            
            REPLY=""
            read -p "${BLUE}Select with user name to migrate:${NC} " REPLY
            
            if [ ${REPLY} -le ${V2USRCOUNT} ]
            then
              # Based on selection, assign from array of USR
              USRNAME="${USR[${REPLY}]}"
              
              export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
              export ENERGI3_HOME=${USRHOME}/energi3
              
              if [ -f ${ENERGI3_HOME}/etc/migrated_to_v3.log ]
              then
                echo "${RED}*** Energi v2 for user ${USRNAME} has already been migrated to Energi v3 ***${NC}"
                echo "${RED}***                           Exiting Installer                          ***${NC}"
                exit 0
                
              else
                INSTALLTYPE=migrate
                echo "Energi will be migrated from v2 to v3 as ${GREEN}${USRNAME}${NC}"
                
              fi
              
            else
              echo "${RED}Invalid entry:${NC} Enter a number less than or equal to ${V3USRCOUNT}"
              _check_install
              
            fi
            
          else
            USRNAME=nrgstaker
            INSTALLTYPE=new
            echo "Installing new version of Energi v3 as ${USRNAME}"
            echo "Existing Energi v2 needs to be manually migrated to Energi v3"
            
            _add_nrgstaker
            
            export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
            export ENERGI3_HOME=${USRHOME}/energi3
            
          fi
               
          ;;
      esac
      
      # Clean-up temporary file
      rm ${CHKV2USRTMP}
      ;;
      
    1)
      #
      # Upgrade existing version of Energi 3:
      #   * One instance of Energi v3 is already installed
      #   * energi3.ipc file exists
      #   * Version on computer is older than version in Github
      # 
      export USRNAME=`cat ${CHKV3USRTMP}`
      INSTALLTYPE=upgrade
      echo "The script will latest version available in Github and upgrade installed"
      echo "Energi v3 if necessary as ${BLUE}${USRNAME}${NC}"
      
      export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
      export ENERGI3_HOME=${USRHOME}/energi3
      
      ;;
  
    *)
      #
      # Upgrade existing version of Energi 3:
      #   * More than one instance of Energi v3 is already installed
      #   * energi3.ipc file exists
      #   * Version on computer is older than version in Github
      #   * User selects which instance to upgrade
      #
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
      read -p "${BLUE}Select with user name to upgrade:${NC} " REPLY
      
      if [ ${REPLY} -le ${V3USRCOUNT} ]
      then
        export USRNAME=${USR[${REPLY}]}
        INSTALLTYPE=upgrade
        
        export USRHOME=`grep "^${USRNAME}:" /etc/passwd | awk -F: '{print $6}'`
        export ENERGI3_HOME=${USRHOME}/energi3

      else
        echo "${RED}Invalid entry:${NC} Enter a number less than or equal to ${V3USRCOUNT}"
        echo "               Starting over"
        _check_install
      fi
      
      echo "Upgrading Energi v3 as ${USRNAME}"
      
      ;;
  
  esac
  
  # Clean-up temporary file
  rm ${CHKV3USRTMP}

}

_setup_appdir () {

  CHK_HOME='n'
  while [ ${CHK_HOME} != "y" ]
  do
    echo "Enter Full Path of where you wall to install Energi3 Node Software"
    read -r -p "(${ENERGI3_HOME}): " TMP_HOME
    if [ "${TMP_HOME}" != "" ]
    then
      export ENERGI3_HOME=${TMP_HOME}
    fi
    read -n 1 -p "Is Install path correct: ${ENERGI3_HOME} (y/N): " CHK_HOME
    echo
    CHK_HOME=${CHK_HOME,,}    # tolower
  done
  
  echo "Energi v3 will be installed in ${ENERGI3_HOME}"
  sleep 0.5
  # Set application directories
  export BIN_DIR=${ENERGI3_HOME}/bin
  export ETC_DIR=${ENERGI3_HOME}/etc
  export JS_DIR=${ENERGI3_HOME}/js
  export PW_DIR=${ENERGI3_HOME}/.secure
  export TMP_DIR=${ENERGI3_HOME}/tmp

  # Create directories if it does not exist
  if [ ! -d ${BIN_DIR} ]
  then
    echo "Creating directory: ${BIN_DIR}"
    mkdir -p ${BIN_DIR}
  fi
  if [ ! -d ${ETC_DIR} ]
  then
    echo "Creating directory: ${ETC_DIR}"
    mkdir -p ${ETC_DIR}
  fi
  if [ ! -d ${JS_DIR} ]
  then
    echo "Creating directory: ${JS_DIR}"
    mkdir -p ${JS_DIR}
  fi
  if [ ! -d ${TMP_DIR} ]
  then
    echo "Creating directory: ${TMP_DIR}"
    mkdir -p ${TMP_DIR}
  fi
  
  echo "Changing ownership of ${ENERGI3_HOME} to ${USRNAME}"
  ${SUDO} chown -R ${USRNAME}:${USRNAME} ${ENERGI3_HOME}
  
}

_check_ismainnet () {

  # Confirm Mainnet or Testnet
  # Default: Mainnet
  if [[ "${INSTALLTYPE}" == "new" ]]
  then
    isMainnet=y
    read -n 1 -p "Are you setting up Mainnet ([y]/n): " isMainnet
    isMainnet=${isMainnet,,}    # tolower

    if [[ "${isMainnet}" == 'y' ]] || [[ -z "${isMainnet}" ]]
    then
      export CONF_DIR=${USRHOME}/.energicore3
      export FWPORT=39797
      export isMainnet=y
      echo "The application will be setup for Mainnet"
    else
      export CONF_DIR=${USRHOME}/.energicore3/testnet
      export FWPORT=49797
      export isMainnet=n
      echo "The application will be setup for Testnet"
    fi

  elif [[ "${INSTALLTYPE}" == "upgrade" ]]
  then
    if [ ! -d "${USRNAME}/.energicore3/testnet" ]
    then
      export CONF_DIR=${USRHOME}/.energicore3
      export FWPORT=39797
      export isMainnet=y
      echo "The application will be setup for Mainnet"
    else
      export CONF_DIR=${USRHOME}/.energicore3/testnet
      export FWPORT=49797
      export isMainnet=n
      echo "The application will be setup for Testnet"
    fi
    
  else
    # INSTALLTYPE = migrate
    if [ ! -d "${USRNAME}/.energicore/testnet" ]
    then
      export CONF_DIR=${USRHOME}/.energicore3
      export FWPORT=39797
      export isMainnet=y
      echo "The application will be setup for Mainnet"
    else
      export CONF_DIR=${USRHOME}/.energicore3/testnet
      export FWPORT=49797
      export isMainnet=n
      echo "The application will be setup for Testnet"
    fi
  fi
  sleep 0.3
}

_stop_energi3 () {

  # Check if energi3 process is running and stop it
  ENERGI3PID=`ps -ef | grep energi3 | grep -v "grep energi3" | grep -v "color=auto" | awk '{print $2}' `
  if [ ! -z "${ENERGI3PID}" ]
  then
    echo "Stopping Energi v3"
    echo "Code to stop energi3 to be added"
    sleep 3
  fi
}

_install_apt () {

  # Check if any apt packages need installing or upgrade
  # Setup server to auto updating security related packages automatically
  if [ ! -x "$( command -v aria2c )" ] || [ ! -x "$( command -v unattended-upgrade )" ] || [ ! -x "$( command -v ntpdate )" ] || [ ! -x "$( command -v google-authenticator )" ] || [ ! -x "$( command -v php )" ] || [ ! -x "$( command -v jq )" ]  || [ ! -x "$( command -v qrencode )" ]
  then
    echo "Updating linux first."
    echo "Running apt-get update."
    sleep 2
    ${SUDO} apt-get update -yq
    echo "Running apt-get upgrade."
    sleep 2
    ${SUDO} apt-get upgrade -yq
    echo "Running apt-get dist-upgrade."
    sleep 2
    ${SUDO} apt-get -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

    if [ ! -x "$( command -v unattended-upgrade )" ]
    then
      echo "Running apt-get install unattended-upgrades php ufw."
      sleep 1
      ${SUDO} apt-get install -yq unattended-upgrades php ufw
      
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
      python3-pip \
      python-pip \
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
      dbus-user-session
  fi
  
  if [ ! -x "$( command -v jq )" ]
  then
    ${SUDO} apt-get install -yq jq
  fi
  ${SUDO} apt-get install -yq screen
  ${SUDO} apt-get install -yq nodejs
  
  echo "Removing apt files not required"
  ${SUDO} apt autoremove -y
  
}

_add_logrotate () {

  # Setup log rotate
  # Logs in $HOME/.energicore3 will rotate automatically when it reaches 100M
  if [ ! -f /etc/logrotate.d/energi3 ]
  then
    echo "Setting up log maintenance for energi3"
    sleep 0.3
    cat << ENERGI3_LOGROTATE | ${SUDO} tee /etc/logrotate.d/energi3 >/dev/null
${CONF_DIR}/*.log {
  su ${USRNAME} ${USRNAME}
  rotate 3
  minsize 100M
  copytruncate
  compress
  missingok
}
ENERGI3_LOGROTATE

  logrotate -f /etc/logrotate.d/energi3
  
  fi
}

_install_energi3 () {

  # Name of scripts
  #NODE_SCRIPT=start_staking.sh
  #MN_SCRIPT=start_mn.sh
  NODE_SCRIPT=run_linux.sh
  MN_SCRIPT=run_mn_linux.sh
  JS_SCRIPT=utils.js
  
  # Check Github for URL of latest version
  if [ -z "${GITHUB_LATEST}" ]
  then
    GITHUB_LATEST=`curl -s ${API_URL}`
  fi
  BIN_URL=$( echo "${GITHUB_LATEST}" | jq -r '.assets[].browser_download_url' | grep -v debug | grep -v '.sig' | grep linux )
 
  # Download from repositogy
  echo "Downloading Energi Core Node and scripts"
  cd ${BIN_DIR}
  if [ -f "${ENERGI3_EXE}" ]
  then
    mv ${ENERGI3_EXE} ${ENERGI3_EXE}.old
  fi
  ${SUDO} wget -4qo- "${BIN_URL}" -O "${ENERGI3_EXE}" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  chmod 755 ${ENERGI3_EXE}
  chown ${USRNAME}:${USRNAME} ${ENERGI3_EXE}
  
  if [ -f "${NODE_SCRIPT}" ]
  then
    mv ${NODE_SCRIPT} ${NODE_SCRIPT}.old
  fi  
  wget -4qo- "${SCRIPT_URL}/scripts/${NODE_SCRIPT}?dl=1" -O "${NODE_SCRIPT}" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  chmod 755 ${NODE_SCRIPT}
  chown ${USRNAME}:${USRNAME} ${NODE_SCRIPT}

  if [ -f "${MN_SCRIPT}" ]
  then
    mv ${MN_SCRIPT} ${MN_SCRIPT}.old
  fi  
  wget -4qo- "${SCRIPT_URL}/scripts/${MN_SCRIPT}?dl=1" -O "${MN_SCRIPT}" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  chmod 755 ${MN_SCRIPT}
  chown ${USRNAME}:${USRNAME} ${MN_SCRIPT}

  cd ${JS_DIR}
  if [ -f "${JS_SCRIPT}" ]
  then
    mv ${JS_SCRIPT} ${JS_SCRIPT}.old
  fi
  wget -4qo- "${SCRIPT_URL}/js/${JS_SCRIPT}?dl=1" -O "${JS_SCRIPT}" --show-progress --progress=bar:force:noscroll 2>&1
  sleep 0.3
  chmod 644 ${JS_SCRIPT}
  chown ${USRNAME}:${USRNAME} ${JS_SCRIPT}
  
  # Change to install directory
  cd
  
}

_version_gt() { 

  # Check if FIRST version is greater than SECOND version
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
  
}

_upgrade_energi3 () {

  # Get the latest version from Github 
  GITHUB_LATEST=$( curl -s ${API_URL} )
  GIT_VERSION=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
  
  # Extract latest version number without the 'v'
  GIT_LATEST=$( echo ${GIT_VERSION} | sed 's/v//g' )
  
  # Installed Version
  INSTALL_VERSION=$( ${BIN_DIR}/${ENERGI3_EXE} version | grep "^Version" | awk '{ print $2 }' | awk -F\- '{ print $1 }' 2>/dev/null )
  
  if _version_gt ${GIT_LATEST} ${INSTALL_VERSION}; then
    echo "Installing newer version ${GIT_VERSION} from Github"
    _install_energi3
  else
    echo "Latest version of Energi v3 is installed: ${INSTALL_VERSION}"
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
  REPLY=''
  read -p "Make it so only the above list of users can login via SSH ([y]/n)?: " -r
  REPLY=${REPLY,,} # tolower
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
  if [[ ! -x "$( command -v  ufw )" ]]
  then
    echo "Installing missing package to secure server"
    ${SUDO} apt-get install -yq ufw
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
  ${SUDO} ufw enable
  
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
    # shellcheck disable=SC2086
    ${SUDO} apt-get install -yq ${NEW_PACKAGES}

    ${SUDO} service apache2 stop 2>/dev/null
    ${SUDO} update-rc.d apache2 disable 2>/dev/null
    ${SUDO} update-rc.d apache2 remove 2>/dev/null
  fi

  if [[ ! -f "${ETC_DIR}/otp.php" ]]
  then
    cd ${ETC_DIR}
    wget -4qo- ${SCRIPT_URL}/thirdparty/otp.php -O "otp.php" --show-progress --progress=bar:force:noscroll 2>&1
    ${SUDO} chmod 644 "${ETC_DIR}/otp.php"
    cd -
  fi
  
  if [[ ${EUID} = 0 ]]
  then
    ${SUDO} chown ${USRNAME}:${USRNAME} "${ETC_DIR}/otp.php"
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
    chown ${USRNAME}:${USRNAME} "${USRHOME}/.google_authenticator.temp"
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
      touch "${USRHOME}/.ssh/authorized_keys"
      chmod 644 "${USRHOME}/.ssh/authorized_keys"
      echo "${SSH_RSA_PUBKEY}" >> "${USRHOME}/.ssh/authorized_keys"
      echo "Added ${SSH_TEST}"
      echo
      break
    fi

    rm "${TEMP_RSA_FILE}"
  done
}

_check_clock() {
  if [ ! -x "$( command -v ntpdate )" ]
  then
    ${SUDO} apt-get install -yq ntpdate
  fi
  echo "Checking system clock..."
  ${SUDO} ntpdate -q pool.ntp.org | tail -n 1 | grep -o 'offset.*' | awk '{print $1 ": " $2 " " $3 }'
}

_add_swap () {
  # Add 2GB additional swap
  if [ ! /var/swapfile ]
  then
    ${SUDO} fallocate -l 2G /var/swapfile
    ${SUDO} chmod 600 /var/swapfile
    ${SUDO} mkswap /var/swapfile
    ${SUDO} swapon --label swap-2g /var/swapfile

    ${SUDO} echo -e "/var/swapfile\t none\t swap\t sw\t 0\t 0" >> /etc/fstab
    echo "Added 2GB swap space to the server"
  else
    echo "No additional swap space added"
  fi
}

_copy_keystore() {

  # Copy Energi v3 keystore file to computer

  # Download ffsend if needed
    # Install ffsend and jq as well.
  if [ ! -x "$( command -v snap )" ] || [ ! -x "$( command -v jq )" ] || [ ! -x "$( command -v column )" ]
  then
    ${SUDO} apt-get install -yq snap
    ${SUDO} apt-get install -yq snapd
    ${SUDO} apt-get install -yq jq bsdmainutils
  fi
  if [ ! -x "$( command -v ffsend )" ]
  then
    ${SUDO} snap install ffsend
  fi

  if [ ! -x "$( command -v ffsend )" ]
  then
    FFSEND_URL=$( wget -4qO- -o- https://api.github.com/repos/timvisee/ffsend/releases/latest | jq -r '.assets[].browser_download_url' | grep static | grep linux )
    cd "${ENERGI3_HOME}/bin/"
    wget -4q -o- "${FFSEND_URL}" -O "ffsend"
    chmod 755 "ffsend"
    cd -
  fi
  
  echo
  echo "This script uses https://send.firefox.com/ to transfer files from your"
  echo "desktop computer onto the vps. You can read more about the service here"
  echo "https://en.wikipedia.org/wiki/Firefox_Send"
  sleep 5
  echo
  echo "Target: ${CONF_DIR}/keystore"
  echo "Shutdown your desktop Energi v3 node and upload the keystore file to"
  echo "https://send.firefox.com/"
  sleep 2
  echo "Start your desktop Energi v3 node."
  echo "Paste in the url to your keystore file below."
  sleep 2
  echo
  REPLY=''
  while [[ -z "${REPLY}" ]] || [[ "$( echo "${REPLY}" | grep -c 'https://send.firefox.com/download/' )" -eq 0 ]]
  do
    read -p "URL (leave blank to do it manually (sftp/scp)): " -r
    if [[ -z "${REPLY}" ]]
    then      
      echo "Please copy the keystore file to ${CONF_DIR}/keystore directory on your own"
      read -p "Press Enter Once Done: " -r
      ${SUDO} chown "${USRNAME}":"${USRNAME}" "${CONF_DIR}/keystore/UTC*"
      ${SUDO} chmod 600 "${CONF_DIR}/keystore/UTC*"
    fi
  done

  while :
  do
    TEMP_DIR_NAME1=$( mktemp -d -p "${USRHOME}" )
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
    if [[ -f "${ENERGI3_HOME}/bin/ffsend" ]]
    then
      "${ENERGI3_HOME}/bin/ffsend" download -y --verbose "${REPLY}" -o "${TEMP_DIR_NAME1}/"
    else
      ffsend download -y --verbose "${REPLY}" -o "${TEMP_DIR_NAME1}/"
    fi

    KEYSTOREFILE=$( find "${TEMP_DIR_NAME1}/" -type f )
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
      chown "${USRNAME}":"${USRNAME}" ${CONF_DIR}/keystore
      KEYSTORE_EXIST=''
    fi
    
    if [[ ! -z "${KEYSTORE_EXIST}" ]]
    then
      echo "Backing up ${BASENAME} file"
      ${SUDO} mkdir -p ${ENERGI3_HOME}/backups
      ${SUDO} mv "${CONF_DIR}/keystore/${BASENAME}" "${ENERGI3_HOME}/backups/${BASENAME}.bak"
      ${SUDO} chown "${USRNAME}":"${USRNAME}" ${ENERGI3_HOME}/backups
    fi
    
    #
    ${SUDO} mv "${KEYSTOREFILE}" "${CONF_DIR}/keystore/${BASENAME}"   
    ${SUDO} chmod 600 "${CONF_DIR}/keystore/${BASENAME}"
    ${SUDO} chown "${USRNAME}":"${USRNAME}" "${CONF_DIR}/keystore/${BASENAME}"
    
    echo "Keystore Account ${ACCTNUM} copied to vps"

  done
  
  # Remove temp directory
  rm -rf "${TEMP_DIR_NAME1:?}"

}

_migrate_wallet () {

  #V3WALLET_BALANCE=$( energi-cli getbalance )
  ENERGI2PID=`ps -ef | grep energid | grep -v "grep energid" | grep -v "color=auto" | awk '{print $2}'`
  if [ ! -z "${ENERGI2PID}" ]
  then
      V2WALLET_BALANCE=$( energi-cli getbalance )
  fi
  
  if [[ "${V2WALLET_BALANCE}" == 0 ]]
  then
    echo "Current balance of the Energi v2 wallet on this computer is ${V2WALLET_BALANCE} NRG"
    echo "Nothing to to migrate to Energi v3.  Continuing..."
    return
  else
    echo "Current balance of the Energi v2 wallet on this computer is ${V2WALLET_BALANCE} NRG"
    read -s -p "Enter passphrase for Energi v2 wallet: " WALLET2PASS
    if [ ! -z "${WALLET2PASS}" ]
    then
      energi-cli walletpassphrase ${WALLET2PASS} 999
      OTTTMPFILE=$( mktemp -p "${TMP_DIR}" )
      energi-cli dumpwallet ${TMP_DIR}/energi2wallet.dump 2> ${OTTTMPFILE}
      OTTPASS=`cat ${OTTTMPFILE} | grep "ONE TIME" | awk '{ print $5 }'`
      energi-cli dumpwallet ${TMP_DIR}/energi2wallet.dump ${OTTPASS}
      V2BLOCKCOUNT=$( energi-cli getblockcount )
      
    else
      echo "No passphrase entered for Energi v2 Wallet.  Nothing to migrate"
      sleep 2
      return
    fi
  fi
  
  if [[ -f ${TMP_DIR}/energi2wallet.dump ]]
  then
    if [[ "${isMainnet}" = 'y' ]]
    then
      if [[ "${V2BLOCKCOUNT}" = "${MAINNETSSBLOCK}" ]]
      then
        echo "Code to import into v3 goes here..."
        sleep 3
      else
        echo "Energi v2 needs to sync with Network to start migration to Energi v3."
        echo "The Snapshot Block ${MAINNETSSBLOCK} has not been reached"
        sleep 0.3
        return
      fi
      
    else
      if [[ "${V2BLOCKCOUNT}" = "${TESTNETSSBLOCK}" ]]
      then
        echo "Code to import into v3 goes here..."
        sleep 3
      else
        echo "Energi v2 needs to sync with Network to start migration to Energi v3."
        echo "The Snapshot Block ${MAINNETSSBLOCK} has not been reached"
        sleep 0.3
        return
      fi 
    fi
    sleep 3
  fi
}

_setup_keystore_auto_pw () {

  # Create secure directory
  if [[ ! -d "${PW_DIR}" ]]
  then
    mkdir -p "${PW_DIR}"
    chown ${USRNAME}:${USRNAME} ${PW_DIR}
    chown 700 ${PW_DIR}
  fi

  # See if node is unlocked for staking.
  NODE_UNLOCKED=$( echo "true" )
  
  if [[ "${NODE_UNLOCKED}" != 'true' ]]
  then
    echo "Energi v3 Node is not running.  Cannot update passwords"
    echo "Continuing..."
    sleep 3
    return
  fi
  
  for KS in `ls ${CONF_DIR}/keystore`
  do
    unset PWACCTNUM
    unset BASENAME
    BASENAME=$( basename ${KS} )
    PWACCTNUM="0x`echo ${BASENAME} | awk -F\-\- '{ print $3 }'`"

    rm -f "${ENERGI3_HOME}/.secure/${BASENAME}.pwd" 2>/dev/null
    unset PASSWORD
    unset CHARCOUNT
    echo -n "Set password for account ${PWACCTNUM}: "
    stty -echo

    CHARCOUNT=0
    PROMPT=''
    CHAR=''
    while IFS= read -p "${PROMPT}" -r -s -n 1 CHAR
    do
      # Enter - accept password
      if [[ "${CHAR}" == $'\0' ]]
      then
        break
      fi
      # Backspace
      if [[ "${CHAR}" == $'\177' ]]
      then
        if [[ "${CHARCOUNT}" -gt 0 ]]
        then
          CHARCOUNT=$(( CHARCOUNT - 1 ))
          PROMPT=$'\b \b'
          PASSWORD="${PASSWORD%?}"
        else
          PROMPT=''
        fi
      else
        CHARCOUNT=$((CHARCOUNT+1))
        PROMPT='*'
        PASSWORD+="$CHAR"
      fi
    done
    stty echo

    echo
    touch "${PW_DIR}/${BASENAME}.pwd"
    chown ${USRNAME}:${USRNAME} "${PW_DIR}/${BASENAME}.pwd"
    chmod 600 "${PW_DIR}/${BASENAME}.pwd"
    echo "${PASSWORD}" > "${PW_DIR}/${BASENAME}.pwd"

    # ==> Command to start with unlock password
    echo "Placeholder: enter script to start node"
    sleep 0.5
  done
  
  unset PASSWORD
  unset CHARCOUNT

  # Output info.
  echo "Placeholder"
  echo
  V2WALLET_BALANCE=$( energi-cli getbalance )
  STAKE_INPUTS=$( energi-cli liststakeinputs )
  STAKING_BALANCE=$( echo "${STAKE_INPUTS}" | jq '.[].amount' 2>/dev/null | awk '{s+=$1} END {print s}' 2>/dev/null )
  STAKING_INPUTS_COUNT=$( echo "${STAKE_INPUTS}" | grep -c 'amount' )
  echo -e "Current wallet.dat balance: \e[1m${V2WALLET_BALANCE}\e[0m"
  echo -e "Value of coins that can stake: \e[1m${STAKING_BALANCE}\e[0m"
  echo -e "Number of staking inputs: \e[1m${STAKING_INPUTS_COUNT}\e[0m"
  echo "Node info: ${USRNAME} ${CONF_FILE}"
  echo "Staking Status:"
  energi-cli getstakingstatus | grep -C 20 --color -E '^|.*false'
  CONF_FILE_BASENAME=$( basename "${CONF_FILE}" )
  echo
  echo
  echo
  echo "Start or Restart your desktop wallet after adding the line below to the"
  echo "desktop wallet's conf file ${CONF_FILE_BASENAME}. You can edit it from "
  echo "the desktop wallet by going to Tools -> Open Wallet Configuration File"
  echo
  echo "staking=0"
  echo

}

_ascii_logo () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
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
ENERGI3
echo -n ${NC}
}

_ascii_logo_bottom () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
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
ENERGI3
echo -n ${NC}
}

_ascii_logo_2 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
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
ENERGI3
echo -n ${NC}
}

_ascii_logo_3 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
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
ENERGI3
echo -n ${NC}
}

_ascii_logo_4 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
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
ENERGI3
echo -n ${NC}
}

_ascii_logo_5 () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
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
ENERGI3
echo -n ${NC}
}

_ascii_logo_top () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
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
ENERGI3
echo -n ${NC}
}

#_menu_option_new () {
#  echo "${NC}"
#  cat << "ENERGIMENU"
# Options:
#    a) New server installation of Energi v3
#
#
#    x) Exit without doing anything
#ENERGIMENU
#}

_menu_option_new () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) New server installation of Energi v3"
echo "${GREEN}    \::/  /    ${NC}"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

#_menu_option_mig () {
#  echo "${NC}"
#  cat << "ENERGIMENU"
# Options:
#    a) Upgrade Energi v2 to v3; automatic wallet migration
#    b) Upgrade Energi v2 to v3; manual wallet migration
#    
#    x) Exit without doing anything
#ENERGIMENU
#}

_menu_option_mig () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) Upgrade Energi v2 to v3; automatic wallet migration"
echo "${GREEN}    \::/  /    ${NC}   b) Upgrade Energi v2 to v3; manual wallet migration"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

#_menu_option_upgrade () {
#  echo "${NC}"
#  cat << "ENERGIMENU"
# Options:
#    a) Upgrade version of Energi v3
#    b) Install monitoring on Discord and/or Telegram
#    
#    x) Exit without doing anything
#ENERGIMENU
#}

_menu_option_upgrade () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Options:"
echo "${GREEN}   \:\/:/  /   ${NC}   a) Upgrade version of Energi v3"
echo "${GREEN}    \::/  /    ${NC}"
echo "${GREEN}     \/__/     ${NC}   x) Exit without doing anything"
echo ${NC}
}

#_welcome_instructions () {
#  echo "${NC}"
#  echo -e "Welcome to the Energi v3 Installer. You can use this script to:
# - ${BLUE}New Installation :${NC} No previous version of Energi exists on the computer
# - ${BLUE}Upgrade          :${NC} Upgrade from a previous version of Energi
# - ${BLUE}Migrate          :${NC} Migrate from Energi v2 to Energi v3"
#  read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."
#}

_welcome_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Welcome to the Energi v3 Installer."
echo "${GREEN}   \:\/:/  /   ${NC}- New Install : No previous installs"
echo "${GREEN}    \::/  /    ${NC}- Upgrade     : Upgrade previous version"
echo "${GREEN}     \/__/     ${NC}- Migrate     : Migrate from Energi v2"
echo ${NC}
read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."
}

#_end_instructions () {
#  echo "${NC}"
#  echo -e "Thank you for your support of Energi! We wish you a successful staking.
# Login as ${USRNAME} and run the following script to start/stop the Node:
#    - ${BLUE}start_node.sh${NC}    Use the script to start the Node
#    - ${BLUE}stop_node.sh${NC}     Use the script to stop the Node
# For instructions visit:
# ${DOC_URL}"
#echo
#}

_end_instructions () {
  echo "${GREEN}"
  clear 2> /dev/null
  cat << "ENERGI3"
      ___       ______ _   _ ______ _____   _____ _____ ____
     /\  \     |  ____| \ | |  ____|  __ \ / ____|_   _|___ \
    /::\  \    | |__  |  \| | |__  | |__) | |  __  | |   __) |
   /:/\:\__\   |  __| | . ` |  __| |  _  /| | |_ | | |  |__ <
  /:/ /:/ _/_  | |____| |\  | |____| | \ \| |__| |_| |_ ___) |
 /:/ /:/ /\__\ |______|_| \_|______|_|  \_\\_____|_____|____/
 \:\ \/ /:/  /
ENERGI3
echo "${GREEN}  \:\  /:/  /  ${NC}Thank you for supporting Energi! Good luck staking."
echo "${GREEN}   \:\/:/  /   ${NC}Run the following script to start/stop the Node:"
echo "${GREEN}    \::/  /    ${NC}- start_node.sh    Use the script to start the Node"
echo "${GREEN}     \/__/     ${NC}- stop_node.sh     Use the script to stop the Node"
echo ${NC}
echo "For instructions visit: ${DOC_URL}"
echo
}


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Main Program
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

#TEMP_FILENAME1=$( mktemp )
#SP="/-\\|"

# Make installer interactive and select normal mode by default.
INTERACTIVE="y"
ADVANCED="n"
POSITIONAL=()

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -a|--advanced)
        ADVANCED="y"
        shift
        ;;
    -n|--normal)
        ADVANCED="n"
        UFW="y"
        BOOTSTRAP="y"
        shift
        ;;
    -i|--externalip)
        EXTERNALIP="$2"
        ARGUMENTIP="y"
        shift
        shift
        ;;
    --bindip)
        BINDIP="$2"
        shift
        shift
        ;;
    -k|--privatekey)
        KEY="$2"
        shift
        shift
        ;;
    -u|--ufw)
        UFW="y"
        shift
        ;;
    --no-ufw)
        UFW="n"
        shift
        ;;
    -b|--bootstrap)
        BOOTSTRAP="y"
        shift
        ;;
    --no-bootstrap)
        BOOTSTRAP="n"
        shift
        ;;
    --no-interaction)
        INTERACTIVE="n"
        shift
        ;;
    -d|--debug)
        set -x
        shift
        ;;
    -h|--help)
        cat << EOL

Energi3 installer arguments:

    -n --normal               : Run installer in normal mode
    -a --advanced             : Run installer in advanced mode
    -i --externalip <address> : Public IP address of VPS
    --bindip <address>        : Internal bind IP to use
    -k --privatekey <key>     : Private key to use
    -u --ufw                  : Install UFW
    --no-ufw                  : Do not install UFW
    -b --bootstrap            : Sync node using Bootstrap
    --no-bootstrap            : Do not use Bootstrap
    -h --help                 : Display this help text
    --no-interaction          : Do not wait for wallet activation
    -d --debug                : Debug mode

EOL
        exit
        ;;
    *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift
        ;;
  esac
done


#
# Clears screen and present Energi v3 logo
_ascii_logo_bottom
sleep 0.3
_ascii_logo_2
sleep 0.3
_ascii_logo_3
sleep 0.3
_ascii_logo_4
sleep 0.3
_ascii_logo_5
sleep 0.3
_welcome_instructions

# Check architecture
_os_arch
# Check Install type and set ENERGI3_HOME
_check_install
read -t 10 -p "Wait 10 sec or Press [ENTER] key to continue..."

# Present menu to choose an option based on Installation Type determined
case ${INSTALLTYPE} in
  new)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Scenario:
    #   * No energi3.ipc file on the computer
    #   * No energi.conf file on the computer
    #
    # Menu Options
    #   a) New server installation of Energi v3
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    _menu_option_new
    
    REPLY='x'
    read -p "Please select an option to get started (a, b, or x): " -r
    REPLY=${REPLY,,} # tolower
    if [ "${REPLY}" = "" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # New server installation of Energi v3
        
        # ==> Run as root / sudo <==
        _install_apt
        _restrict_logins
        _check_ismainnet
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
        
        # Check if user wants to install RSA for key based login
        REPLY=''
        read -p "Do you want to install RSA Key [Y/n]?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
        then
          _add_rsa_key
        fi

        #
        # ==> Run as user <==
        #
        _setup_appdir
        _install_energi3
        
        REPLY=''
        read -p "Do you want to download keystore account file to the computer (y/[n])?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]]
        then
          _copy_keystore
        fi

        REPLY=''
        read -p "Do you want to auto start Energi v3 Node after computer reboots ([y]/n)?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
        then
          _setup_keystore_auto_pw
        fi
        
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
    #   * $ENERGI3_HOME/etc/migrated_to_v3.log exists
    #
    # Menu Options
    #   a) Upgrade version of Energi v3
    #   b) Install monitoring on Discord and/or Telegram
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    _menu_option_upgrade
    
    REPLY='x'
    read -p "Please select an option to get started (a, b, or x): " -r
    REPLY=${REPLY,,} # tolower
    
    if [ "x${REPLY}" = "x" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # Upgrade version of Energi v3
        _stop_energi3
        _install_apt
        _restrict_logins
        _check_ismainnet
        _secure_host
        _check_clock
        _add_swap
        _add_logrotate
        
        if [[ -s "${USRHOME}/.google_authenticator" ]]
        then
          # 2FA not installed. Ask if user wants to install
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
        fi
        
        if [[ -s "${USRHOME}/.ssh/authorized_keys" ]]
        then
          # Check if user wants to install RSA for key based login
          REPLY=''
          read -p "Do you want to install RSA Key [[y]/n]?: " -r
          REPLY=${REPLY,,} # tolower
          if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
          then
            _add_rsa_key
          fi
        fi

        #
        # ==> Run as user <==
        #
        _setup_appdir
        _upgrade_energi3
        
        REPLY=''
        read -p "Do you want to auto start Energi v3 Node after computer reboots ([y]/n)?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
        then
          _setup_keystore_auto_pw
        fi
        
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
  
  migrate)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Scenario:
    #   * No energi3.ipc file on the computer
    #   * energi3.ipc file exists on the computer
    #   * Keystore file does not exists
    #   * $ENERGI3_HOME/etc/migrated_to_v3.log exists
    #
    # Menu Options
    #   a) Migrate from Energi v2 to v3; automatic wallet migration
    #   b) Migrate Energi v2 to v3; manual wallet migration
    #   x) Exit without doing anything
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    _menu_option_mig
    
    REPLY='x'
    read -p "Please select an option to get started (a, b, or x): " -r
    REPLY=${REPLY,,} # tolower
    
    if [ "${REPLY}" = "" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # Install packages
        _install_apt
        _restrict_logins
        _check_ismainnet
        _secure_host
        _check_clock
        _add_swap
        _add_logrotate
        
        if [[ -s "${USRHOME}/.google_authenticator" ]]
        then
          # 2FA not installed. Ask if user wants to install
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
        fi
        
        if [[ -s "${USRHOME}/.ssh/authorized_keys" ]]
        then
          # Check if user wants to install RSA for key based login
          REPLY=''
          read -p "Do you want to install RSA Key [[y]/n]?: " -r
          REPLY=${REPLY,,} # tolower
          if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
          then
            _add_rsa_key
          fi
        fi

        #
        # ==> Run as user <==
        #
        _setup_appdir
        _install_energi3
        
        REPLY=''
        read -p "Do you want to download keystore account file to the computer (y/[n])?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]]
        then
          _copy_keystore
        fi
        
        _start_energiv3
        
        REPLY=''
        read -p "Do you want the script to migrate Energi v2 wallet to v3 (y/[n])?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]]
        then
          _migrate_wallet
        else
          echo "You have chosen to manually migrate Energi v2 Wallet to v3. Please"
          echo "look at the website for details on how to manually migrate using"
          echo "Energi Core Wallet and MEW or Energi v3 Node."
          sleep 3
        fi
        
        REPLY=''
        read -p "Do you want to auto start Energi v3 Node after computer reboots ([y]/n)?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
        then
          _setup_keystore_auto_pw
        fi
        
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


# End of Installer