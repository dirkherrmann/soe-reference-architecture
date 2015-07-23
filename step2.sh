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
NAME="acme-rhev-munich"
DESC="RHEV Infrastructure located in munich"
USER="admin@internal"
#PASS="changeme"
PASS="redhat"
#URL="https://rhevm.example.com/api"
URL="https://inf2.coe.muc.redhat.com/api"
PROVIDER="Ovirt"
ORG="ACME"
LOC="munich"

hammer compute-resource create \
        --name ${NAME} \
        --description "${DESC}" \
        --user "${USER}" \
        --password "${PASS}" \
        --url "${URL}" \
        --provider "${PROVIDER}" \
        --organizations "${ORG}" \
        --locations "${LOC}"

##########################################################
#          COMPUTE RESOURCE  DMZ  LOCATION               #
##########################################################
NAME="acme-rhev-munich-dmz"
DESC="RHEV Infrastructure located in munich-dmz"
USER="admin@internal"
PASS="redhat"
URL="https://inf2.coe.muc.redhat.com/api"
PROVIDER="Ovirt"
ORG="ACME"
LOC="munich"

hammer compute-resource create \
        --name ${NAME} \
        --description "${DESC}" \
        --user "${USER}" \
        --password "${PASS}" \
        --url "${URL}" \
        --provider "${PROVIDER}" \
        --organizations "${ORG}" \
        --locations "${LOC}"

##########################################################
#          COMPUTE RESOURCE REMOTE LOCATION              #
##########################################################
NAME="acme-rhelosp-boston"
DESC="Red Hat Enterprise Linux OpenStack Platform located in boston"
USER="acmeadmin"
PASS="redhat"
URL="http://inf44.coe.muc.redhat.com:5000/v2.0/tokens"
PROVIDER="Openstack"
TENANT="r&d"
ORG="ACME"
LOC="boston"

hammer compute-resource create \
        --locations "${LOC}" \
        --name "${NAME}" \
        --organizations "${ORG}" \
        --provider "${PROVIDER}" \
        --url "${URL}" \
        --tenant "${TENANT}" \
        --user "${USER}" \
        --password "${PASS}"

##########################################################
#          DOMAINS                                       #
##########################################################
#munich
ORG="ACME"
DOMAIN="example.com"
LOCATION="munich"
DNSPROXY="inf60.coe.muc.redhat.com"
hammer domain create --name "${DOMAIN}"
hammer domain update --name "${DOMAIN}" --dns "${DNSPROXY}"
hammer domain update --name "${DOMAIN}" --organizations "${ORG}"
hammer domain update --name "${DOMAIN}" --locations "${LOCATION}"

#munich-dmz
ORG="ACME"
DOMAIN="dmz.example.com"
LOCATION="munich-dmz"
hammer domain create --name "${DOMAIN}"
hammer domain update --name "${DOMAIN}" --organizations "${ORG}"
hammer domain update --name "${DOMAIN}" --locations "${LOCATION}"

#boston
ORG="ACME"
DOMAIN="novalocal"
LOCATION="boston"
hammer domain create --name "${DOMAIN}"
hammer domain update --name "${DOMAIN}" --organizations "${ORG}"
hammer domain update --name "${DOMAIN}" --locations "${LOCATION}"

##########################################################
#          SUBNETS					 #
##########################################################
DOMAIN="example.com"
ORG="ACME"
LOC="munich"
DNS_PRIMARY="172.24.96.254"
SUBNET_MASK="255.255.255.0"
SUBNET_NETWORK="172.24.96.0"
SUBNET_IPAM_START="172.24.96.100"
SUBNET_IPAM_END="172.24.96.200"

CAPSULE_ID=1
hammer subnet create --name "${DOMAIN}" \
        --organizations "${ORG}" \
        --locations "${LOC}" \
        --domains "${DOMAIN}" \
        --boot-mode "Static" \
        --dns-primary "${DNS_PRIMARY}" \
        --mask "${SUBNET_MASK}" \
        --network "${SUBNET_NETWORK}" \
        --gateway "${SUBNET_GATEWAY}" \
        --from "${SUBNET_IPAM_START}" \
        --to "${SUBNET_IPAM_END}" \
        --ipam "DHCP" \
        --dhcp-id "${CAPSULE_ID}" \
        --dns-id "${CAPSULE_ID}" \
        --tftp-id "${CAPSULE_ID}"

DOMAIN="dmz.example.com"
ORG="ACME"
LOC="munich-dmz"
DNS_PRIMARY="172.24.99.254"
SUBNET_MASK="255.255.255.0"
SUBNET_NETWORK="172.24.99.0"
SUBNET_IPAM_START="172.24.99.100"
SUBNET_IPAM_END="172.24.99.200"

hammer subnet create --name "${DOMAIN}" \
        --organizations "${ORG}" \
        --locations "${LOCATIONS}" \
        --domains "${DOMAIN}" \
        --boot-mode "Static" \
        --dns-primary "${DNS_PRIMARY}" \
        --mask "${SUBNET_MASK}" \
        --network "${SUBNET_NETWORK}" \
        --gateway "${SUBNET_GATEWAY}" \
        --from "${SUBNET_IPAM_START}" \
        --to "${SUBNET_IPAM_END}" \
        --ipam "DHCP" 

DOMAIN="novalocal"
ORG="ACME"
LOC="munich-dmz"
SUBNET_MASK="255.255.255.0"
SUBNET_NETWORK="10.0.40.0"

hammer subnet create --name "${DOMAIN}" \
        --mask "${SUBNET_MASK}" \
        --network "${SUBNET_NETWORK}" \
        --organizations "${ORG}" \
        --locations "${LOCATIONS}" \
        --domains "${DOMAIN}"




