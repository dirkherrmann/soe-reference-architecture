#! /bin/bash

# this is step where we expect to have an already installed satellite 6 and create the configuration for all further steps, the main org and subscriptions

# TODO short desc and outcome of this step

DIR="$PWD"
source "${DIR}/common.sh"

# check if organization already exists. if yes, exit
hammer organization info --name "$ORG" >/dev/null 2>&1 
if $? -ne 0; then  
  echo "Organization $ORG already exists. Exit."
  exit 1
fi

# create org
hammer organization create --name "$ORG" --label "$ORG_LABEL" --description "$ORG_DESCRIPTION"

if [ -f $subscription_manifest_loc ]; then
# upload manifest
hammer subscription upload --organization "$ORG" --file "$subscription_manifest_loc"
else
 echo "please upload your manifest to the Satellite Server and specify the location in $HOME/.soe-config"
 exit 1
fi

# note: has worked for me only at the second try, so maybe we should check if successful before proceeding:
hammer subscription list --organization "$ORG" | ( grep -q 'Red Hat' && echo ok ) || ( echo "Subscription import has not been successful. Exit"; exit 1 )

# TODO Ben: Compute Resources here from old step6.sh / now step7.sh
