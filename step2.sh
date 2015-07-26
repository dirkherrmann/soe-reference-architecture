DIR="$PWD"
source "${DIR}/common.sh"

TMPIFS=$IFS
IFS=","
##########################################################
# 		   create location                       #
##########################################################
for LOC in ${LOCATIONS}
do
  hammer location create --name "${LOC}"
  hammer location add-organization --name "${LOC}" --organization "${ORG}"
done
IFS=$TMPIFS

##########################################################
#          COMPUTE RESOURCE  MAIN LOCATION               #
##########################################################
if [ -n "${COMPUTE_NAME1}" ]; then
hammer compute-resource create \
        --name ${COMPUTE_NAME1} \
        --description "${COMPUTE_DESC1}" \
        --user "${COMPUTE_USER1}" \
        --password "${COMPUTE_PASS1}" \
        --url "${COMPUTE_URL1}" \
        --provider "${COMPUTE_PROVIDER1}" \
        --organizations "${ORG}" \
        --locations "${LOCATION1}"
fi

##########################################################
#          COMPUTE RESOURCE  DMZ  LOCATION               #
##########################################################
if [ -n "$COMPUTE_NAME2" ]; then
hammer compute-resource create \
        --name ${COMPUTE_NAME2} \
        --description "${COMPUTE_DESC2}" \
        --user "${COMPUTE_USER2}" \
        --password "${COMPUTE_PASS2}" \
        --url "${COMPUTE_URL2}" \
        --provider "${COMPUTE_PROVIDER2}" \
        --organizations "${ORG}" \
        --locations "${LOCATION2}"
fi

##########################################################
#          COMPUTE RESOURCE REMOTE LOCATION              #
##########################################################
if [ -n "$COMPUTE_NAME3" ]; then
hammer compute-resource create \
        --locations "${LOCATION3}" \
        --name "${COMPUTE_NAME3}" \
        --organizations "${ORG}" \
        --provider "${COMPUTE_PROVIDER3}" \
        --url "${COMPUTE_URL3}" \
        --tenant "${COMPUTE_TENANT3}" \
        --user "${COMPUTE_USER3}" \
        --password "${COMPUTE_PASS3}"
fi

##########################################################
#          DOMAINS                                       #
##########################################################
#munich
hammer domain create --name "${DOMAIN1}"
if [ -n "$DNSPROXY" ]; then
hammer domain update --name "${DOMAIN1}" --dns "${DNSPROXY}"
fi
hammer domain update --name "${DOMAIN1}" --organizations "${ORG}"
hammer domain update --name "${DOMAIN1}" --locations "${LOCATION1}"

#munich-dmz
if [ -n "${DOMAIN2}" ]; then
hammer domain create --name "${DOMAIN2}"
hammer domain update --name "${DOMAIN2}" --organizations "${ORG}"
hammer domain update --name "${DOMAIN2}" --locations "${LOCATION2}"
fi

#boston
if [ -n "${DOMAIN3}" ]; then
hammer domain create --name "${DOMAIN3}"
hammer domain update --name "${DOMAIN3}" --organizations "${ORG}"
hammer domain update --name "${DOMAIN3}" --locations "${LOCATION3}"
fi

##########################################################
#          SUBNETS					 #
##########################################################
CAPSULE_ID=1
hammer subnet create --name "${DOMAIN1}" \
        --organizations "${ORG}" \
        --locations "${LOCATION1}" \
        --domains "${DOMAIN1}" \
        --boot-mode "Static" \
        --dns-primary "${DNS_PRIMARY1}" \
        --mask "${SUBNET_MASK1}" \
        --network "${SUBNET_NETWORK1}" \
        --gateway "${SUBNET_GATEWAY1}" \
        --from "${SUBNET_IPAM_START1}" \
        --to "${SUBNET_IPAM_END1}" \
        --ipam "DHCP" \
        --dhcp-id "${CAPSULE_ID}" \
        --dns-id "${CAPSULE_ID}" \
        --tftp-id "${CAPSULE_ID}"

if [ -n "$SUBNET_MASK2" ]; then
hammer subnet create --name "${DOMAIN2}" \
        --organizations "${ORG}" \
        --locations "${LOCATION2}" \
        --domains "${DOMAIN2}" \
        --boot-mode "Static" \
        --dns-primary "${DNS_PRIMARY2}" \
        --mask "${SUBNET_MASK2}" \
        --network "${SUBNET_NETWORK2}" \
        --gateway "${SUBNET_GATEWAY2}" \
        --from "${SUBNET_IPAM_START2}" \
        --to "${SUBNET_IPAM_END2}" \
        --ipam "DHCP" 
fi

if [ -n "$SUBNET_MASK3" ]; then
hammer subnet create --name "${DOMAIN3}" \
        --mask "${SUBNET_MASK3}" \
        --network "${SUBNET_NETWORK3}" \
        --organizations "${ORG}" \
        --locations "${LOCATION3}" \
        --domains "${DOMAIN3}"
fi
