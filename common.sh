#! /bin/bash

# Common functions for all the step scripts

export LANG=en_US.utf8

CONFIGFILE=$HOME/.soe-config

while getopts :c:h FLAG; do
  case $FLAG in
    c)
      CONFIGFILE=$OPTARG
      ;;
    h) 
      SCRIPT="${BASH_SOURCE[1]}"
      echo ""
      echo "$SCRIPT [options]"
      echo "        -c filename   : the path to a config file"
      echo ""
      exit 1
      ;;
  esac
done

# check if the config exists and if yes source the config file 
if  [ ! -f $CONFIGFILE ]; then
  echo "Could not find configuration file. Please copy the example file into your home directory and adapt it accordingly!"
  echo "# cp <path to your github copy>/soe-reference-architecture/soe-config.example ~/.soe-config" 
  echo "or use -c to pass in a path to the config file"
  exit 1
fi

source $CONFIGFILE 

# Setup hammer based on the configurations
mkdir  -p $HOME/.hammer  
cat > $HOME/.hammer/cli_config.yml <<EOF 
:foreman:  
 :host: $SATELLITE_SERVER
 :username: $SATELLITE_USER
 :password: $SATELLITE_PASSWORD  
 :organization: $ORG
EOF

if [ "$ECHO_COMMANDS" == 1 ]; then
  set -x
fi
