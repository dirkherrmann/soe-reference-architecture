#! /bin/bash

# this is step where we expect to have an already installed satellite 6 and create the configuration for all further steps, the main org and subscriptions

# TODO ask for all configuration values and create the config file

# check if exists and if yes source the config file 
if  [ ! -f ~/.soe-config ]; then
  echo "Could not find configuration file. Please copy the example file into your home directory and adapt it accordingly!"
  echo "# cp <path to your github copy>/soe-reference-architecture/soe-config.example ~/.soe-config"
  exit 1
fi

source ~/.soe-config

echo $ORG

# this functions creates the yaml configuration file for hammer usage
mkdir  -p ~/.hammer  
cat > ~/.hammer/cli_config.yml <<EOF 
:foreman:  
 :host: $SATELLITE_SERVER
 :username: $SATELLITE_USER
 :password: $SATELLITE_PASSWORD  
 :organization: $ORG_NAME
EOF

# check if organization already exists. if yes, exit
#hammer organization info --name $ORG >/dev/null 2>&1 && echo "Organization $ORG already exists. Exit."; exit 1

# create org
hammer organization create --name "$ORG" --label "$ORG_LABEL" --description "$ORG_DESCRIPTION"

# upload manifest
hammer subscription upload --organization "$ORG" --file "$subscription_manifest_loc"

# note: has worked for me only at the second try, so maybe we should check if successful before proceeding:
hammer subscription list --organization "$ORG" | grep -q 'Red Hat Enterprise Linux Server' && echo ok || echo "Subscription import has not been successful. Exit"; exit

