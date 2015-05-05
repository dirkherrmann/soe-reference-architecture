#! /bin/bash

# Common functions for all the step scripts

# check if the config exists and if yes source the config file 
if  [ ! -f $HOME/.soe-config ]; then
  echo "Could not find configuration file. Please copy the example file into your home directory and adapt it accordingly!"
  echo "# cp <path to your github copy>/soe-reference-architecture/soe-config.example ~/.soe-config"
  exit 1
fi

source $HOME/.soe-config

# Setup hammer based on the configurations
mkdir  -p $HOME/.hammer  
cat > $HOME/.hammer/cli_config.yml <<EOF 
:foreman:  
 :host: $SATELLITE_SERVER
 :username: $SATELLITE_USER
 :password: $SATELLITE_PASSWORD  
 :organization: $ORG
EOF

echo "$ECHO_COMMANDS" 


if [ "$ECHO_COMMANDS" == 1 ]; then
  set -x
fi
