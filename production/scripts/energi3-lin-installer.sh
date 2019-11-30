#!/bin/bash

#####################################################################
# Copyright (c) 2019
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
bash -ic "$(wget -4qO- -o- https://raw.githubusercontent.com/energicryptocurrency/energi3/master/scripts/energi3-lin-installer.sh)" ; source ~/.bashrc
```
'
#####################################################################

### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Global Variables
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

# Uncomment to debug
#set -x

# Locations of Repositories and Guide
API_URL='https://api.github.com/repos/energicryptocurrency/energi3/releases/latest'
SCRIPT_URL='https://raw.githubusercontent.com/zalam003/EnergiCore3/master/publictest'
DOC_URL='https://github.com/energicryptocurrency/energi3/blob/master/README.md'

# Energi v3 Bootstrap Settings
#export BLK_HASH=gsaqiry3h1ho3nh
#export BOOTSTRAP_URL="https://www.dropbox.com/s/%BLK_HASH%/blocks_n_chains.tar.gz"

# Set Executables & Configuration
export ENERGI3_EXE=energi3
export ENERGI3_CONF=energi3.toml

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
  # Check OS Architecture (32-bit or 64-bit)
  echo -n "Checking if OS architecture is supported: "
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

_check_user () {
  RUNAS=`whoami`

  if [ "${RUNAS}" != "root" ]
  then
    echo "${RED}*** You need to run the script as ${NC}root${RED}.   ***${NC}"
    echo "${RED}*** Exiting the script. Login as ${NC}root${RED} and ***${NC}"
    echo "${RED}*** run the script again.                  ***${NC}"
    exit 0  
  fi
  
  CHKV3USRTMP=/tmp/chk_v3_usr.tmp
  find /home -name energi3.ipc | awk -F\/ '{print $3}' > ${CHKV3USRTMP}
  find /root -name energi3.ipc | awk -F\/ '{print $3}' >> ${CHKV3USRTMP}
  V3USRCOUNT=`wc -l ${CHKV3USRTMP} | awk '{ print $1 }'`
  
  case ${V3USRCOUNT} in
  
    0)
      #
      # Energiv3 Not Installed
      # ================
      #
      # New:
      # v2 is not installed or already has been mograted
      # 
      # Migration:
      # if energi.conf and energid exists assume a migration
      # Check for file: migrated_to_v3.log
      #
      echo -n "Checking if Energi v2 is installed:       "
      CHKV2USRTMP=/tmp/chk_v2_usr.tmp
      find /home -name energi.conf | awk -F\/ '{print $3}' > ${CHKV2USRTMP}
      find /root -name energi.conf | awk -F\/ '{print $3}' >> ${CHKV2USRTMP}
      V2USRCOUNT=`wc -l ${CHKV2USRTMP} | awk '{ print $1 }'`
      
      case ${V2USRCOUNT} in
        0)
          echo "${YELLOW}V2 Not installed${NC}"
          echo
          # Set username
          USRNAME=nrgstaker
          INSTALLTYPE=new
          CHKPASSWD=`grep ${USRNAME} /etc/passwd`
          if [ "x${CHKPASSWD}" = "x" ]
          then
            echo "${GREEN}*** Creating user ${USRNAME} ***${NC}"
            adduser --gecos "Energi Staking Account" --quiet ${USRNAME}
            usermod -aG sudo ${USRNAME}
          fi
          ;;
        
        *)
          echo "${GREEN}V2 is installed${NC}"
          echo
          echo "You have two options to install Energi v3:"
          echo "  1) Use the same user as used in Energi v2"
          echo "  2) Create a separate installation with a new installation"
          echo
          echo "For both options you can choose to manually migrate the wallet or automatically"
          echo "migrate all funds from Energi v2 to Energi v3."
          echo
          isMigrate=""
          read -p "Do you want to migrate from Energi v2 to v3 (y/N): "
          isMigrate=${isMigrate,,}    # tolower
          
          if [ "${isMigrate}" = "y" ]
          then
            I=1
            for U in `cat ${CHKV2USRTMP}`
            do
              # Create an array of USR
              USR[${I}]=${U}
              echo "${I}: ${USR[${I}]}"
              if [ ${I} != ${V2USRCOUNT} ]
              then
                ((I=I+1))
              else
                break
              fi
            done
            
            REPLY=""
            read -p "${BLUE}Select with user name to migrate:${NC} " REPLY
            
            if [ ${REPLY} -le ${V2USRCOUNT} ]
            then
              # Based on selection, assign from array of USR
              USRNAME=${USR[${REPLY}]}
              if [ -f /home/${USRNAME}/.energicore/migrated_to_v3.log ]
              then
                echo "${RED}*** Energi v2 for user ${USRNAME} has already been migrated to Energi v3 ***${NC}"
                echo "${RED}***                           Exiting Installer                          ***${NC}"
                exit 0
              else
                INSTALLTYPE=migrate
                echo "${RED}Migrate:${NC} Energi will be migrated from v2 to v3 as ${USRNAME}"
              fi
            else
              echo "${RED}Invalid entry:${NC} Enter a number less than or equal to ${V3USRCOUNT}"
              _check_user
            fi
            
          else
            USRNAME=nrgstaker
            INSTALLTYPE=new
            echo "${RED}New Install:${NC} Installing new version of Energi v3 as ${USRNAME}"
            echo "${RED}No Migration:${NC} Exiting Energi v2 will need to be manually migrated to Energi v3"
            CHKPASSWD=`grep ${USRNAME} /etc/passwd`
            if [ "x${CHKPASSWD}" = "x" ]
            then
              echo "${GREEN}*** Creating user ${USRNAME} ***${NC}"
              adduser --gecos "Energi Staking Account" --quiet ${USRNAME}
              usermod -aG sudo ${USRNAME}
            fi
          fi
          
          sleep 3
          ;;
      esac
      
      # Clean-up temporary file
      rm ${CHKV2USRTMP}
      ;;
      
    1)
      #
      # Energi v3 has been already installed
      # Check if a new version needs to be installed
      # 
      USRNAME=`cat ${CHKV3USRTMP}`
      INSTALLTYPE=upgrade
      echo "${RED}Upgrade:${NC} Energi v3 will be upgraded if required as ${BLUE}${USRNAME}${NC}"
      
      sleep 3
      ;;
  
    *)
      # If more than one username was used to install Energi v3, ask which one to use
      I=1
      for U in `cat ${CHKV3USRTMP}`
      do
        #echo "${U}"
        USR[${I}]=${U}
        echo "${I}: ${USR[${I}]}"
        if [ $I != ${V3USRCOUNT} ]
        then
          ((I=I+1))
        else
          break
        fi
      done
      REPLY=""
      read -p "Select with user name to use: " REPLY
      
      if [ ${REPLY} -le ${V3USRCOUNT} ]
      then
        USRNAME=${USR[${REPLY}]}
        INSTALLTYPE=upgrade
      else
        echo "${RED}Invalid entry:${NC} Enter a number less than or equal to ${V3USRCOUNT}"
        echo "               Starting over"
        _check_user
      fi
      
      echo "${RED}Upgrade:${NC} Upgrading Enegi v3 as ${USRNAME}"
      
      sleep 3
      ;;
  
  esac
  
  # Clean-up temporary file
  rm ${CHKV3USRTMP}
  
  # Set Default Install Directory
  export USR_HOME=/home/${USRNAME}
  export ENERGI3_HOME=${USR_HOME}/energi3
}


_setup_appdir () {

  CHK_HOME=N
  while [ ${CHK_HOME} != y ]
  do
    echo "Enter Full Path of where you wall to install Energi3 Node Software"
    read -r -p "(${ENERGI3_HOME}): " TMP_HOME
    if [ "x${TMP_HOME}" != "x" ]
    then
      export ENERGI3_HOME=${TMP_HOME}
    fi
    read -n 1 -p "Is Install path correct: ${ENERGI3_HOME} (y/N): " CHK_HOME
    echo
    CHK_HOME=${CHK_HOME,,}    # tolower
  done
  
  echo "Energi v3 will be installed in ${ENERGI3_HOME}"
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
  chown -R ${USRNAME}:${USRNAME} ${ENERGI3_HOME}
  
}

_check_ismainnet () {

  # Confirm Mainnet or Testnet
  # Default: Mainnet
  export isMainnet=y
  read -n 1 -p "Are you setting up Mainnet [Y]/n: " isMainnet
  isMainnet=${isMainnet,,}    # tolower

  if [[ "${isMainnet}" == 'y' ]] || [[ -z "${isMainnet}" ]]
  then
    export CONF_DIR=${ENERGI3_HOME}/.energicore3
    export FWPORT=39797
    export isMainnet=y
    echo "The application will be setup for Mainnet"
  else
    export CONF_DIR=${ENERGI3_HOME}/.energicore3/testnet
    export FWPORT=49797
    export isMainnet=n
    echo "The application will be setup for Testnet"
  fi
  
}

_install_apt () {
  if [ ! -x "$( command -v aria2c )" ] || [ ! -x "$( command -v unattended-upgrade )" ] || [ ! -x "$( command -v ntpdate )" ] || [ ! -x "$( command -v google-authenticator )" ] || [ ! -x "$( command -v php )" ] || [ ! -x "$( command -v jq )" ]  || [ ! -x "$( command -v qrencode )" ]
  then
    echo "Updating linux first."
    sleep 1
    echo "Running apt-get update."
    sleep 2
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -yq
    echo "Running apt-get upgrade."
    sleep 2
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
    echo "Running apt-get dist-upgrade."
    sleep 2
    sudo DEBIAN_FRONTEND=noninteractive apt-get -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

    if [ ! -x "$( command -v unattended-upgrade )" ]
    then
      echo "Running apt-get install unattended-upgrades php ufw."
      sleep 1
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq unattended-upgrades php ufw
      if [ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]
      then
        # Enable auto updating of Ubuntu security packages.
        cat << UBUNTU_SECURITY_PACKAGES | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
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
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
      curl \
      pwgen \
      ufw \
      lsof \
      util-linux \
      gzip \
      unzip \
      unrar \
      xz-utils \
      procps \
      jq \
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
  
  echo "Removing apt files not required"
  sudo apt autoremove -y
  
}

_add_logrotate () {

  # Setup log rotate
  if [ ! -f /etc/logrotate.d/energi3 ]
  then
    cat << ENERGI3_LOGROTATE | sudo tee /etc/logrotate.d/energi3 >/dev/null
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
  
  # Get the latest version from Github 
  GITHUB_LATEST=`curl -s ${API_URL}`
  BIN_URL=$( echo "${GITHUB_LATEST}" | jq -r '.assets[].browser_download_url' | grep -v debug | grep -v '.sig' | grep linux )
  GIT_VERSION=$( echo "${GITHUB_LATEST}" | jq -r '.tag_name' )
  
  # Extract latest version number without the 'v'
  LASTEST=`echo ${GIT_VERSION} | sed 's/v//g'`
  
  # Download from repositogy
  echo "Downloading Energi Core Node and scripts"
  wget -4qo- "${BIN_URL}" -O "${BIN_DIR}/${ENERGI3_EXE}" --show-progress --progress=bar:force 2>&1
  sleep 0.3
  chmod 755 ${BIN_DIR}/${ENERGI3_EXE}
  chown ${USRNAME}:${USRNAME} ${BIN_DIR}/${ENERGI3_EXE}
  
  wget -4qo- "${SCRIPT_URL}/scripts/${NODE_SCRIPT}?dl=1" -O "${BIN_DIR}/${NODE_SCRIPT}" --show-progress --progress=bar:force 2>&1
  sleep 0.3
  chmod 755 ${BIN_DIR}/${NODE_SCRIPT}
  chown ${USRNAME}:${USRNAME} ${BIN_DIR}/${NODE_SCRIPT}
  
  wget -4qo- "${SCRIPT_URL}/scripts/${MN_SCRIPT}?dl=1" -O "${BIN_DIR}/${MN_SCRIPT}" --show-progress --progress=bar:force 2>&1
  sleep 0.3
  chmod 755 ${BIN_DIR}/${MN_SCRIPT}
  chown ${USRNAME}:${USRNAME} ${BIN_DIR}/${MN_SCRIPT}

  wget -4qo- "${SCRIPT_URL}/js/${JS_SCRIPT}?dl=1" -O "${JS_DIR}/${JS_SCRIPT}" --show-progress --progress=bar:force 2>&1
  sleep 0.3
  chmod 644 ${JS_DIR}/${JS_SCRIPT}
  chown ${USRNAME}:${USRNAME} ${BIN_DIR}/${MN_SCRIPT}
  
}


_restrict_logins() {
  # Secure server by restricting who can login
  
  # Have linux passwords show stars.
  if [[ -f /etc/sudoers ]] && [[ $( sudo grep -c 'env_reset,pwfeedback' /etc/sudoers ) -eq 0 ]]
  then
    echo "Show password feeback."
    sudo cat /etc/sudoers | sed -r 's/^Defaults(\s+)env_reset$/Defaults\1env_reset,pwfeedback/' | sudo EDITOR='tee ' visudo >/dev/null
    echo "Restarting ssh."
    sudo systemctl restart sshd
  fi

  USRS_THAT_CAN_LOGIN=$( whoami )
  USRS_THAT_CAN_LOGIN="root ubuntu ${USRNAME} ${USRS_THAT_CAN_LOGIN}"
  USRS_THAT_CAN_LOGIN=$( echo "${USRS_THAT_CAN_LOGIN}" | xargs -n1 | sort -u | xargs )
  ALL_USERS=$( cut -d: -f1 /etc/passwd )

  BOTH_LISTS=$( sort <( echo "${USRS_THAT_CAN_LOGIN}" | tr " " '\n' ) <( echo "${ALL_USERS}" | tr " " '\n' ) | uniq -d | grep -Ev "^$" )
  if [[ $( grep -cE '^AllowUsers' /etc/ssh/sshd_config ) -gt 0 ]]
  then
    USRS_THAT_CAN_LOGIN_2=$( grep -E '^AllowUsers' /etc/ssh/sshd_config | sed -e 's/^AllowUsers //g' )
    BOTH_LISTS=$( echo "${USRS_THAT_CAN_LOGIN_2} ${BOTH_LISTS}" | xargs -n1 | sort -u | xargs )
    MISSING_FROM_LISTS=$( join -v 2 <(sort <( echo "${USRS_THAT_CAN_LOGIN_2}" | tr " " '\n' ))  <(sort <( echo "${BOTH_LISTS}" | tr " " '\n' ) ))
  else
    MISSING_FROM_LISTS="${BOTH_LISTS}"
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
  echo "${BOTH_LISTS}"
  REPLY=''
  read -p "Make it so only the above list of users can login via SSH (y/n)?: " -r
  REPLY=${REPLY,,} # tolower
  if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
  then
    if [[ $( grep -cE '^AllowUsers' /etc/ssh/sshd_config ) -eq 0 ]]
    then
      echo "AllowUsers ${BOTH_LISTS}" >> /etc/ssh/sshd_config
    else
      sudo sed -ie "/AllowUsers/ s/$/ ${MISSING_FROM_LISTS} /" /etc/ssh/sshd_config
    fi
    USRS_THAT_CAN_LOGIN=$( grep -E '^AllowUsers' /etc/ssh/sshd_config | sed -e 's/^AllowUsers //g' | tr " " '\n' )
    echo "Restarting ssh."
    sudo systemctl restart sshd
    echo "List of users that can login via SSH (/etc/ssh/sshd_config):"
    echo "${USRS_THAT_CAN_LOGIN}"
  fi
}

_secure_host() {
  # Enable Local Firewall
  echo "Limiting ssh and ${FWPORT} port access to server"
  ufw allow ssh/tcp
  ufw limit ssh/tcp
  ufw allow ${FWPORT}/tcp
  ufw allow ${FWPORT}/udp
  ufw logging on
  ufw enable
}

_setup_two_factor() {
  sudo service apache2 stop 2>/dev/null
  sudo update-rc.d apache2 disable 2>/dev/null
  sudo update-rc.d apache2 remove 2>/dev/null

  # Ask to review if .google_authenticator file already exists.
  if [[ -s "${USR_HOME}/.google_authenticator" ]]
  then
    REPLY=''
    read -p "Review 2 factor authentication code for password SSH login (y/n)?: " -r
    REPLY=${REPLY,,} # tolower
    if [[ "${REPLY}" == 'n' ]] || [[ -z "${REPLY}" ]]
    then
      return
    fi
  fi

  # Clear out an old failed run.
  if [[ -f "${USR_HOME}/.google_authenticator.temp" ]]
  then
    rm "${USR_HOME}/.google_authenticator.temp"
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
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq ${NEW_PACKAGES}

    sudo service apache2 stop 2>/dev/null
    sudo update-rc.d apache2 disable 2>/dev/null
    sudo update-rc.d apache2 remove 2>/dev/null
  fi

  if [[ -f "${ETC_DIR}/otp.php" ]]
  then
    cp "${ETC_DIR}/otp.php" "${USR_HOME}/___otp.php"
  else
    wget -4qo- ${SCRIPT_URL}/otp.php -O "${USR_HOME}/___otp.php" --show-progress --progress=bar:force 2>&1
    cp "${USR_HOME}/___otp.php" "${ETC_DIR}/otp.php"
    chown ${USRNAME}:${USRNAME} "${ETC_DIR}/otp.php"
    chmod 644 "${ETC_DIR}/otp.php"
  fi

  # Generate otp.
  IP_ADDRESS=$( timeout --signal=SIGKILL 10s wget -4qO- -T 10 -t 2 -o- http://ipinfo.io/ip )
  SECRET=''
  if [[ -f "${USR_HOME}/.google_authenticator" ]]
  then
    SECRET=$( sudo head -n 1 "${USR_HOME}/.google_authenticator" 2>/dev/null )
  fi
  if [[ -z "${SECRET}" ]]
  then
    sudo google-authenticator -t -d -f -r 10 -R 30 -w 5 -q -Q UTF8 -l "ssh login for '${USRNAME}'"
    # Add 5 recovery digits.
    {
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    head -200 /dev/urandom | cksum | tr -d ' ' | cut -c1-8 ;
    } | sudo tee -a  "${USR_HOME}/.google_authenticator" >/dev/null
    SECRET=$( sudo head -n 1 "${USR_HOME}/.google_authenticator" 2>/dev/null )
  fi
  if [[ -z "${SECRET}" ]]
  then
    echo "Google Authenticator install failed."
    return
  fi
  if [[ -f "${USR_HOME}/.google_authenticator" ]]
  then
    mv "${USR_HOME}/.google_authenticator" "${USR_HOME}/.google_authenticator.temp"
    CHMOD_G_AUTH=$( stat --format '%a' ${USR_HOME}/.google_authenticator.temp )
    chmod 666 "${USR_HOME}/.google_authenticator.temp"
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
      rm -f "${USR_HOME}/.google_authenticator"
      rm -f "${USR_HOME}/.google_authenticator.temp"
      echo "Not going to use google authenticator."
      return
    fi

    KEY_CHECK=$( php "${USR_HOME}/___otp.php" "${REPLY}" "${USR_HOME}/.google_authenticator.temp" )
    if [[ ! -z "${KEY_CHECK}" ]]
    then
      echo "${KEY_CHECK}"
      if [[ $( echo "${KEY_CHECK}" | grep -ic 'Key Verified' ) -gt 0 ]]
      then
        break
      fi
    fi
  done

  if [[ -f "${USR_HOME}/.google_authenticator.temp" ]]
  then
    chmod "${CHMOD_G_AUTH}" "${USR_HOME}/.google_authenticator.temp"
    chown ${USRNAME}:${USRNAME} "${USR_HOME}/.google_authenticator.temp"
    mv "${USR_HOME}/.google_authenticator.temp" "${USR_HOME}/.google_authenticator"
  fi

  echo "Your emergency scratch codes are (write these down in a safe place):"
  grep -oE "[0-9]{8}" "${USR_HOME}/.google_authenticator" | awk '{print "  " $1 }'

  read -r -p $'Use this 2 factor code \e[7m(y/n)\e[0m? ' -e 2>&1
  REPLY=${REPLY,,} # tolower
  if [[ "${REPLY}" == 'y' ]]
  then
    if [[ $( grep -c 'auth required pam_google_authenticator.so nullok' /etc/pam.d/sshd ) -eq 0 ]]
    then
      echo "auth required pam_google_authenticator.so nullok" | sudo tee -a "/etc/pam.d/sshd" >/dev/null
    fi
    sudo sed -ie 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
    echo
    echo "If using Bitvise select keyboard-interactive with no submethods selected."
    echo

    # Allow for 20 bad root login attempts before killing the ip.
    if [[ -f /etc/denyhosts.conf ]]
    then
      sudo sed -ie 's/DENY_THRESHOLD_ROOT \= 1/DENY_THRESHOLD_ROOT = 5/g' /etc/denyhosts.conf
      sudo sed -ie 's/DENY_THRESHOLD_RESTRICTED \= 1/DENY_THRESHOLD_RESTRICTED = 5/g' /etc/denyhosts.conf
      sudo sed -ie 's/DENY_THRESHOLD_ROOT \= 1/DENY_THRESHOLD_ROOT = 20/g' /etc/denyhosts.conf
      sudo sed -ie 's/DENY_THRESHOLD_RESTRICTED \= 1/DENY_THRESHOLD_RESTRICTED = 20/g' /etc/denyhosts.conf
      sudo systemctl restart denyhosts
    fi
    sleep 5
    clear
  else
    rm -f "${USR_HOME}/.google_authenticator"
  fi

  # Clean up.
  if [[ -f "${USR_HOME}/___otp.php" ]]
  then
    rm -rf "${USR_HOME}/___otp.php"
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
      touch "${USR_HOME}/.ssh/authorized_keys"
      chmod 644 "${USR_HOME}/.ssh/authorized_keys"
      echo "${SSH_RSA_PUBKEY}" >> "${USR_HOME}/.ssh/authorized_keys"
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
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq ntpdate
  fi
  echo "Checking system clock..."
  ntpdate -q pool.ntp.org | tail -n 1 | grep -o 'offset.*' | awk '{print $1 ": " $2 " " $3 }'
}

_add_swap () {
  # Add 4GB additional swap
  if [ ! /var/swapfile ]
  then
    fallocate -l 4G /var/swapfile
    chmod 600 /var/swapfile
    mkswap /var/swapfile
    swapon /var/swapfile

    echo "/var/swapfile none swap sw 0 0" >> /etc/fstab
    echo "Added 4GB swap space to the server"
  else
    echo "No additional swap space added"
  fi
}

_get_node_info() {
  USRNAME="${1}"
  CONF_FILE="${2}"
  DAEMON_BIN="${3}"
  CONTROLLER_BIN="${4}"

  # Install ffsend and jq as well.
  if [ ! -x "$( command -v snap )" ] || [ ! -x "$( command -v jq )" ] || [ ! -x "$( command -v column )" ]
  then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq snap
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq snapd
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq jq bsdmainutils
  fi
  if [ ! -x "$( command -v ffsend )" ]
  then
    sudo snap install ffsend
  fi

  if [ ! -x "$( command -v ffsend )" ]
  then
    FFSEND_URL=$( wget -4qO- -o- https://api.github.com/repos/timvisee/ffsend/releases/latest | jq -r '.assets[].browser_download_url' | grep static | grep linux )
    mkdir -p "${ENERGI3_HOME}/bin/"
    wget -4q -o- "${FFSEND_URL}" -O "${ENERGI3_HOME}/bin/ffsend"
    chmod +x "${ENERGI3_HOME}/bin/ffsend"
  fi

  # Load in functions.
  stty sane 2>/dev/null
  if [ -z "${PS1}" ]
  then
    PS1="\\"
  fi
  cd "${USR_HOME}" || return 1 2>/dev/null
  source "${USR_HOME}/.bashrc"
  if [ "${PS1}" == "\\" ]
  then
    PS1=''
  fi
  stty sane 2>/dev/null

  # Get info the hard way.
  if [[ -z "${CONF_FILE}" ]] || [[ -z "${DAEMON_BIN}" ]] || [[ -z "${CONTROLLER_BIN}" ]]
  then
    LSLOCKS_OUTPUT=$( sudo lslocks -o COMMAND,PID,PATH | grep -oE ".*/blocks" | sed 's/blocks$//g' )
    if [[ -z "${LSLOCKS_OUTPUT}" ]]
    then
      if [[ ! -z "${DAEMON_BIN}" ]]
      then
        REPLY='y'
        read -p "Install a new ${DAEMON_BIN} node on this vps (y/n)?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]]
        then
          bash -ic "$(wget -4qO- -o- "raw.githubusercontent.com/mikeytown2/masternode/master/${DAEMON_BIN}.sh")" -- NO_MN
          source "${USR_HOME}/.bashrc"
          _get_node_info "${USRNAME}" "${CONF_FILE}" "${DAEMON_BIN}" "${CONTROLLER_BIN}"
        fi
      fi
      return
    fi

    RUNNING_NODES=$( echo "${LSLOCKS_OUTPUT}" | awk '{print $1 " " $3 }' )
    # Filter if daemon bin given.
    if [[ ! -z "${DAEMON_BIN}" ]]
    then
      RUNNING_NODES=$( echo "${RUNNING_NODES}" | grep "^${DAEMON_BIN} " )
    fi
    # Filter if conf file given.
    if [[ ! -z "${CONF_FILE}" ]]
    then
      CONF_DIR=$( dirname "${CONF_FILE}" )
      RUNNING_NODES=$( echo "${RUNNING_NODES}" | grep "${CONF_DIR}" )
    fi
    # Filter if username given.
    if [[ ! -z "${USRNAME}" ]] && [[ $( echo "${RUNNING_NODES}" | grep -c "${USRNAME}" ) -gt 0 ]]
    then
      RUNNING_NODES=$( echo "${RUNNING_NODES}" | grep "${USRNAME}" )
    fi
    if [[ -z "${RUNNING_NODES}" ]]
    then
      return
    fi

    RUNNING_NODES=$( echo "${RUNNING_NODES}" | sort | cat -n | column -t )
    if [[ "$( echo "${RUNNING_NODES}" | wc -l )" -gt 1 ]]
    then
      echo
      echo "Leave blank to exit."
      echo "Select the number of the node you wish to copy your wallet to:"
      echo "${RUNNING_NODES}"
      REPLY=''
      while [[ -z "${REPLY}" ]] || [[ "$( echo "${RUNNING_NODES}" | grep -cE "^${REPLY} " )" -eq 0 ]]
      do
        read -p "Number: " -r
        if [[ -z "${REPLY}" ]]
        then
          return
        fi
      done
    else
      REPLY=1
    fi
    CONF_DIR=$( echo "${RUNNING_NODES}" | grep -E "^${REPLY} " | awk '{print $3}' )
    CONF_FILE=$( grep -rl -m 1 --include \*.conf 'rpcuser\=' "${CONF_DIR}" )

    if [[ -z "${DAEMON_BIN}" ]]
    then
      DAEMON_BIN=$( echo "${RUNNING_NODES}" | grep -E "^${REPLY} " | awk '{print $2}' )
    fi
    if [[ $( echo "${AUTH_LIST}" | grep -c "${DAEMON_BIN}" ) -eq 0 ]]
    then
      return
    fi

    NODE_PID=$( echo "${LSLOCKS_OUTPUT}" | grep "${CONF_DIR}" | awk '{print $2}' )
    if [[ -z "${USRNAME}" ]]
    then
      USRNAME=$( ps -u -p "${NODE_PID}" | tail -n 1 | awk '{print $1}' )
    fi

    if [[ -z "${CONTROLLER_BIN}" ]]
    then
      PID_PATH=$( sudo readlink -f "/proc/${NODE_PID}/exe" )
      if [[ "${#PID_PATH}" -lt 4 ]]
      then
        return
      fi
      if [[ -f "${PID_PATH::-1}-cli" ]]
      then
        CONTROLLER_BIN=$( basename "${PID_PATH::-1}-cli" )
      else
        CONTROLLER_BIN="${DAEMON_BIN}"
      fi
    fi
  fi

  if [[ $( echo "${AUTH_LIST}" | grep -c "${DAEMON_BIN}" ) -eq 0 ]]
  then
    return
  fi

  echo "${USRNAME} ${CONF_FILE} ${DAEMON_BIN} ${CONTROLLER_BIN}" > "${TEMP_FILENAME1}"
  return
}

_copy_keystore() {
  _get_node_info "${1}" "${2}" "${3}" "${4}"
  read -r USRNAME CONF_FILE DAEMON_BIN CONTROLLER_BIN < "${TEMP_FILENAME1}"
  if [[ -z "${CONF_FILE}" ]]
  then
    return
  fi
  CONF_DIR=$( dirname "${CONF_FILE}" )

  # Update mn script.
  cd "${USR_HOME}" || exit
  COUNTER=0
  rm -f "${USR_HOME}/___mn.sh"
  while [[ ! -f "${USR_HOME}/___mn.sh" ]] || [[ $( grep -Fxc "# End of masternode setup script." "${USR_HOME}/___mn.sh" ) -eq 0 ]]
  do
    rm -f "${USR_HOME}/___mn.sh"
    echo "Downloading Setup Script."
    wget -4qo- gist.githack.com/mikeytown2/1637d98130ac7dfbfa4d24bac0598107/raw/mcarper.sh -O "${USR_HOME}/___mn.sh"
    COUNTER=$(( COUNTER + 1 ))
    if [[ "${COUNTER}" -gt 3 ]]
    then
      echo
      echo "Download of setup script failed."
      echo
      exit 1
    fi
  done
  echo "${DAEMON_BIN}"
  if [[ -z "${DAEMON_BIN}" ]]
  then
    echo "Setup encountered an error; please ask for help."
    return
  fi
  sed -i "1iDAEMON_BIN='${DAEMON_BIN}'" "${USR_HOME}/___mn.sh"
  bash "${USR_HOME}/___mn.sh" UPDATE_BASHRC

  # Load in functions.
  stty sane 2>/dev/null
  if [ -z "${PS1}" ]
  then
    PS1="\\"
  fi
  cd "${USR_HOME}" || return 1 2>/dev/null
  source "${USR_HOME}/.bashrc"
  if [ "${PS1}" == "\\" ]
  then
    PS1=''
  fi
  stty sane 2>/dev/null
  rm "${USR_HOME}/___mn.sh"

  # Wait for wallet to load; start if needed.
  _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' wait_for_loaded

  # Wait for mnsync
  MNSYNC_WAIT_FOR='999'
  echo "Waiting for mnsync status..."
  echo "This can sometimes take up 10 minutes; please wait for mnsync."
  i=0
  while [[ $( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' mnsync status | grep -cF "${MNSYNC_WAIT_FOR}" ) -eq 0 ]]
  do
    PERCENT_DONE=$( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' daemon_log tail 2000 | grep -m 1 -o 'nSyncProgress.*\|Progress.*' | tr '=' ' ' | awk -v SF=100 '{printf($2*SF )}' )
    echo -e "\\r${SP:i++%${#SP}:1} Percent Done: %${PERCENT_DONE}      \\c"
    sleep 0.3
  done

  echo
  echo
  WALLET_BALANCE=$( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' getbalance )
  echo "Current wallet.dat balance on this VPS: ${WALLET_BALANCE}"
  if [[ "${WALLET_BALANCE}" != 0 ]]
  then
    REPLY=''
    read -p "Do you want to replace this wallet.dat file (y/n)?: " -r
    REPLY=${REPLY,,} # tolower
    if [[ -z "${REPLY}" ]] || [[ "${REPLY}" == 'n' ]]
    then
      return
    fi
  fi

  echo
  echo "This script uses https://send.firefox.com/ to transfer files from your"
  echo "desktop computer onto the vps. You can read more about the service here"
  echo "https://en.wikipedia.org/wiki/Firefox_Send"
  sleep 5
  echo
  echo "Target: ${CONF_DIR}"
  echo "Please encrypted your wallet.dat file if it is not encrypted."
  sleep 2
  echo "Shutdown your desktop wallet and upload wallet.dat to"
  echo "https://send.firefox.com/"
  sleep 2
  echo "Start your desktop wallet."
  echo "Paste in the url to your wallet.dat file below."
  sleep 2
  echo
  REPLY=''
  while [[ -z "${REPLY}" ]] || [[ "$( echo "${REPLY}" | grep -c 'https://send.firefox.com/download/' )" -eq 0 ]]
  do
    read -p "URL (leave blank do it manually (sftp/scp)): " -r
    if [[ -z "${REPLY}" ]]
    then
      MD5_WALLET_BEFORE=$( sudo md5sum "${CONF_DIR}/wallet.dat" )
      MD5_WALLET_AFTER="${MD5_WALLET_BEFORE}"
      _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' disable
      _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' conf edit staking 1
      while [[ "${MD5_WALLET_BEFORE}" == "${MD5_WALLET_AFTER}" ]]
      do
        echo "Please Copy the wallet.dat file to ${CONF_DIR}/wallet.dat on your own"
        read -p "Press Enter Once Done: " -r
        sudo chown "${USRNAME}":"${USRNAME}" "${CONF_DIR}/wallet.dat"
        sudo chmod 600 "${CONF_DIR}/wallet.dat"
        MD5_WALLET_AFTER=$( sudo md5sum "${CONF_DIR}/wallet.dat" )
        if [[ "${MD5_WALLET_BEFORE}" == "${MD5_WALLET_AFTER}" ]]
        then
          REPLY=''
          read -p "wallet.dat hasn't changed; try again (y/n)?: " -r
          REPLY=${REPLY,,} # tolower
          if [[ "${REPLY}" != 'y' ]]
          then
            break
          fi
        fi
      done
      sudo chown "${USRNAME}":"${USRNAME}" "${CONF_DIR}/wallet.dat"
      sudo chmod 600 "${CONF_DIR}/wallet.dat"
      _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' enable
      # Wait for wallet to load; start if needed.
      _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' wait_for_loaded

      # See if wallet.dat can be opened.
      if [[ $( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' daemon_log tail 500 | grep -c "can't open database wallet.dat" ) -gt 0 ]]
      then
        sudo rm "${CONF_DIR}/wallet.dat"
        echo "Wallet was corrupted; try again. Wallet db version could also be different."
        REPLY=''
      else
        return
      fi
    fi
  done

  DATADIR=$( dirname "${CONF_FILE}" )
  DATADIR_FILENAME=$( echo "${DATADIR}" | tr '/' '_' )


  while :
  do
    TEMP_DIR_NAME1=$( mktemp -d -p "${USR_HOME}" )
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
    fullfile=$( find "${TEMP_DIR_NAME1}/" -type f )
    if [[ -z "${fullfile}" ]]
    then
      echo "Download failed; try again."
      REPLY=''
      continue
    fi
    if [[ $( echo "${fullfile}" | grep -ic 'wallet.dat' ) -gt 0 ]]
    then
      echo "Moving wallet.dat file"
      _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' disable
      _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' conf edit staking 1
      sudo mv "${CONF_DIR}/wallet.dat" "${CONF_DIR}/wallet.dat.bak"
      sudo mv "${fullfile}" "${CONF_DIR}/wallet.dat"
      sudo chown "${USRNAME}":"${USRNAME}" "${CONF_DIR}/wallet.dat"
      sudo chmod 600 "${CONF_DIR}/wallet.dat"
      _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' enable
      # Wait for wallet to load; start if needed.
      _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' wait_for_loaded

      # See if wallet.dat can be opened.
      if [[ $( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' daemon_log tail 500 | grep -c "can't open database wallet.dat" ) -gt 0 ]]
      then
        sudo rm "${CONF_DIR}/wallet.dat"
        sudo mv "${CONF_DIR}/wallet.dat.bak" "${CONF_DIR}/wallet.dat"
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' enable
        # Wait for wallet to load; start if needed.
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' wait_for_loaded
        echo "Wallet db version is different; try again using a dumpwallet file."
        REPLY=''
        rm -rf "${TEMP_DIR_NAME1:?}"
      else
        break
      fi
    else
      if [[ $( grep -ic 'wallet dump' "${fullfile}" ) -gt 0 ]] || [[ $( grep -ic 'label=' "${fullfile}" ) -gt 0 ]]
      then
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' enable
        # Wait for wallet to load; start if needed.
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' wait_for_loaded
        if [[ -f "${USR_HOME}/.pwd/${DATADIR_FILENAME}" ]]
        then
          _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' unlock_wallet_for_staking
        fi
        echo "Importing wallet dump file (Please Wait)"
        BASENAME=$( basename "${fullfile}" )
        # Put labeled addreses at the top.
        grep -i 'label=' "${fullfile}" | sudo tee "${CONF_DIR}/${BASENAME}.txt" >/dev/null
        grep -vi 'label=' "${fullfile}" | sudo tee -a "${CONF_DIR}/${BASENAME}.txt" >/dev/null
        sudo rm -f "${fullfile}"
        sudo chown "${USRNAME}":"${USRNAME}" "${CONF_DIR}/${BASENAME}.txt"
        sudo chmod 600 "${CONF_DIR}/${BASENAME}.txt"
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' importwallet "${CONF_DIR}/${BASENAME}.txt"
        sudo rm -f "${CONF_DIR}/${BASENAME}.txt"
        echo "Restarting wallet to update wallet.dat balance; will take some time."
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' disable
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' conf edit staking 1
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' start-recover
        # Wait for wallet to load; start if needed.
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' wait_for_loaded
        _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' enable
        break
      else
        echo "Unknown File."
        REPLY=''
        read -p "wallet.dat hasn't changed; try again (y/n)?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" != 'y' ]]
        then
          break
        fi
      fi
    fi
  done
  rm -rf "${TEMP_DIR_NAME1:?}"

  rm -f "${ENERGI3_HOME}/.secure/${DATADIR_FILENAME}"

}

_setup_keystore_auto_pw () {
  if [[ ! -f "${TEMP_FILENAME1}" ]]
  then
    return
  fi
  read -r USRNAME CONF_FILE DAEMON_BIN CONTROLLER_BIN < "${TEMP_FILENAME1}"
  if [[ -z "${CONF_FILE}" ]]
  then
    return
  fi
  DATADIR=$( dirname "${CONF_FILE}" )
  DATADIR_FILENAME=$( echo "${DATADIR}" | tr '/' '_' )
  mkdir -p "${ENERGI3_HOME}/.secure/"

  # Load in functions.
  stty sane 2>/dev/null
  if [ -z "${PS1}" ]
  then
    PS1="\\"
  fi
  cd "${USR_HOME}" || return 1 2>/dev/null
  source "${USR_HOME}/.bashrc"
  if [ "${PS1}" == "\\" ]
  then
    PS1=''
  fi
  stty sane 2>/dev/null

 

  # Wait for wallet to load; start if needed.
  

  # Wait for mnsync
  

  # Try to unlock the wallet.
  # ==> command
  sleep 0.5

  # See if wallet is unlocked for staking.
  WALLET_UNLOCKED=$( energi-cli getstakingstatus | jq '.walletunlocked' )

  while [[ "${WALLET_UNLOCKED}" != 'true' ]]
  do
    rm -f "${ENERGI3_HOME}/.secure/${DATADIR_FILENAME}" 2>/dev/null
    unset PASSWORD
    unset CHARCOUNT
    echo -n "Uploaded keystore account file password: "
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
    touch "${ENERGI3_HOME}/.secure/${DATADIR_FILENAME}"
    chmod 600 "${ENERGI3_HOME}/.secure/${DATADIR_FILENAME}"
    echo "${PASSWORD}" > "${ENERGI3_HOME}/.secure/${DATADIR_FILENAME}"

    # ==> Command to start with unlock password

    sleep 0.5
    WALLET_UNLOCKED=$( energi-cli getstakingstatus | jq '.walletunlocked' )

  done
  unset PASSWORD
  unset CHARCOUNT

  # Add cronjob if needed.
  if [[ $( crontab -l 2>/dev/null | grep -cE "\"${USRNAME}\".*unlock_wallet_for_staking" 2>&1 ) -eq 0 ]]
  then
    MINUTES=$(( RANDOM % 60 ))
    ( crontab -l 2>/dev/null ; echo "${MINUTES} * * * * bash -ic 'source /var/multi-masternode-data/.bashrc; _masternode_dameon_2 \"${USRNAME}\" \"${CONTROLLER_BIN}\" \"\" \"${DAEMON_BIN}\" \"${CONF_FILE}\" \"\" \"-1\" \"-1\" unlock_wallet_for_staking 2>&1' 2>/dev/null" ) | crontab -
  fi

  echo
  echo "waiting 30s for staking status to change after unlocking."
  sleep 30

  # Wait for wallet to load; start if needed.
  _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' wait_for_loaded

  # Wait for mnsync
  MNSYNC_WAIT_FOR='999'
  echo "Waiting for mnsync status..."
  echo "This can sometimes take up 10 minutes; please wait for mnsync."
  i=0
  while [[ $( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' mnsync status | grep -cF "${MNSYNC_WAIT_FOR}" ) -eq 0 ]]
  do
    PERCENT_DONE=$( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' daemon_log tail 2000 | grep -m 1 -o 'nSyncProgress.*\|Progress.*' | tr '=' ' ' | awk -v SF=100 '{printf($2*SF )}' )
    echo -e "\\r${SP:i++%${#SP}:1} Percent Done: %${PERCENT_DONE}      \\c"
    sleep 0.3
  done

  # Restart node if staking isn't enabled.
  if [[ $( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' getstakingstatus | jq '.[]' | grep -c 'false' ) -eq 1 ]]
  then
    echo "Restarting the node"
    _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' restart

    # Wait for wallet to load; start if needed.
    _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' wait_for_loaded

    # Wait for mnsync
    MNSYNC_WAIT_FOR='999'
    echo "Waiting for mnsync status..."
    echo "This can sometimes take up 10 minutes; please wait for mnsync."
    i=0
    while [[ $( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' mnsync status | grep -cF "${MNSYNC_WAIT_FOR}" ) -eq 0 ]]
    do
      PERCENT_DONE=$( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' daemon_log tail 2000 | grep -m 1 -o 'nSyncProgress.*\|Progress.*' | tr '=' ' ' | awk -v SF=100 '{printf($2*SF )}' )
      echo -e "\\r${SP:i++%${#SP}:1} Percent Done: %${PERCENT_DONE}      \\c"
      sleep 0.3
    done
    _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' unlock_wallet_for_staking
    echo "waiting 30s for staking status to change after unlocking."
    sleep 30
  fi

  # Output info.
  echo
  WALLET_BALANCE=$( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' getbalance )
  STAKE_INPUTS=$( _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' liststakeinputs )
  STAKING_BALANCE=$( echo "${STAKE_INPUTS}" | jq '.[].amount' 2>/dev/null | awk '{s+=$1} END {print s}' 2>/dev/null )
  STAKING_INPUTS_COUNT=$( echo "${STAKE_INPUTS}" | grep -c 'amount' )
  echo -e "Current wallet.dat balance: \e[1m${WALLET_BALANCE}\e[0m"
  echo -e "Value of coins that can stake: \e[1m${STAKING_BALANCE}\e[0m"
  echo -e "Number of staking inputs: \e[1m${STAKING_INPUTS_COUNT}\e[0m"
  echo "Node info: ${USRNAME} ${CONF_FILE}"
  echo "Staking Status:"
  _masternode_dameon_2 "${USRNAME}" "${CONTROLLER_BIN}" '' "${DAEMON_BIN}" "${CONF_FILE}" '' '-1' '-1' getstakingstatus | grep -C 20 --color -E '^|.*false'
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

_menu_option_new () {
  echo "${NC}"
  cat << "ENERGIMENU"
 Options:
    a) New server installation of Energi v3
    b) Install monitoring on Discord and/or Telegram
    
    x) Exit without doing anything
ENERGIMENU
}

_menu_option_mig () {
  echo "${NC}"
  cat << "ENERGIMENU"
 Options:
    a) Upgrade Energi v2 to v3; automatic wallet migration
    b) Upgrade Energi v2 to v3; manual wallet migration
    
    x) Exit without doing anything
ENERGIMENU
}

_menu_option_upgrade () {
  echo "${NC}"
  cat << "ENERGIMENU"
 Options:
    a) Upgrade version of Energi v3
    b) Install monitoring on Discord and/or Telegram
    
    x) Exit without doing anything
ENERGIMENU
}


_end_instructions () {
  echo "${NC}"
  echo -e "
 Thank you for your support of Energi! We wish you a successful staking.
 Login as ${USRNAME} and run the following script to start/stop the Node:
    - ${BLUE}start_node.sh${NC}    Use the script to start the Node
    - ${BLUE}stop_node.sh${NC}     Use the script to stop the Node
  For instructions visit: ${DOC_URL}"

}


### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
# Main Program
### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###

#REPLY=''
#read -p "Proceed with the script (y/n)?: " -r
#echo
#REPLY=${REPLY,,} # tolower
#if [[ "${REPLY}" == 'n' ]]
#then
#  return 1 2>/dev/null || exit 1
#fi

#TEMP_FILENAME1=$( mktemp )
#SP="/-\\|"

#GITURL=https://raw.githack.com/mikeytown2/masternode/master/stake

# Check architecture
_os_arch

# Check Install type and set ENERGI3_HOME
_check_user

read -p "Press [Enter] key to continue..."

# Present Energi v3 ASCII logo
_ascii_logo

# Present menu to choose an option based on Installation Type determined
case ${INSTALLTYPE} in
  new)
    _menu_option_new
    # a) New server installation of Energi v3
    # b) Install monitoring on Discord and/or Telegram
    # x) Exit without doing anything
    REPLY='x'
    read -p "Please select an option to get started (a, b, or x): " -r
    REPLY=${REPLY,,} # tolower
    if [ "x${REPLY}" = "x" ]
    then
      REPLY='h'
    fi
    
    case ${REPLY} in
      a)
        # New server installation of Energi v3
        
        # => Run as root
        _install_apt
        _restrict_logins
        _check_ismainnet
        _secure_host
        _check_clock
        
        REPLY=''
        read -p "Do you want to install 2-Factor Authenticaion [Y/n]?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
        then
          _setup_two_factor
        fi
        
        REPLY=''
        read -p "Do you want to install RSA Key [Y/n]?: " -r
        REPLY=${REPLY,,} # tolower
        if [[ "${REPLY}" == 'y' ]] || [[ -z "${REPLY}" ]]
        then
          _add_rsa_key
        fi
        
        _add_swap
        _add_logrotate
        
        #sudo -u ${USRNAME} /bin/bash - << DOASUSR
        # => Run as user
        _setup_appdir
        _install_energi3
        
        #_copy_keystore
        #_setup_keystore_auto_pw
        
        #DOASUSR
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
  
  upgrade)
    _menu_option_upgrade
    # a) Upgrade version of Energi v3
    # b) Install monitoring on Discord and/or Telegram
    # x) Exit without doing anything
    REPLY='x'
    read -p "Please select an option to get started (a, b, or x): " -r
    REPLY=${REPLY,,} # tolower
    
    case ${REPLY} in
      a)
        # Upgrade version of Energi v3
        _restrict_logins
        _check_clock
        _setup_two_factor
        _add_swap
        
        ;;
      
      b)
        # Install monitoring on Discord and/or Telegram
        echo "Monitoring functionality to be added"
        
        ;;
        
      x)
        # Exit - Nothing to do
        exit 0
    
        ;;
  
      *)
        clear
        echo "Usage: Please select an option to get started (a, b, c, d or x): "
        echo
        _menu_option
        echo
        exit 0
        ;;
    esac
    
  ;;
  
  migrate)
    _menu_option_mig
    # a) Upgrade Energi v2 to v3; automatic wallet migration
    # b) Upgrade Energi v2 to v3; manual wallet migration
    # x) Exit without doing anything
    REPLY='x'
    read -p "Please select an option to get started (a, b, or x): " -r
    REPLY=${REPLY,,} # tolower
    
  ;;
esac

##
# End installer
##
_ascii_logo
_end_instructions


#rm -rf "${TEMP_FILENAME1}"