#! /bin/bash

# this is step where we expect to have an already installed satellite 6 and create the configuration for all further steps, the main org and subscriptions

# TODO short desc and outcome of this step

DIR="$PWD"
source "${DIR}/common.sh"

# check if organization already exists. if yes, exit
hammer organization info --name "$ORG" >/dev/null 2>&1 
if [ $? -ne 0 ]; then
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

# create compute resource
if [[ -n "${COMPUTE_PROVIDER}" ]] && [[ "${COMPUTE_PROVIDER}" = "Ovirt" ]]
then
  COMPUTE_PROV="RHEV"
  COMPUTE_NAME="${COMPUTE_PROV}-${ORG}-${COMPUTE_LOCATION}"
fi

if [[ -n "$COMPUTE_PROVIDER" ]] ;then
  hammer compute-resource create \
    --name "${COMPUTE_NAME}" \
    --description "${COMPUTE_DESC}" \
    --user "${COMPUTE_USER}" \
    --password "${COMPUTE_PASS}" \
    --url "${COMPUTE_URL}" \
    --provider "${COMPUTE_PROVIDER}" \
    --organizations "${ORG}" \
    --locations "${LOCATIONS}"
    # --uuid  #needed to provide the Datacenter to be used, but name is not sufficient for now
fi
