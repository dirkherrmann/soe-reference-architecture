#!/bin/bash
#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
#
# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture
#
#TODO: add content-views to act-key & HG

if test -f $HOME/.soe-config
then
  source $HOME/.soe-config
else
  echo "Could not find configuration file. Please copy the example file into your home directory and adapt it accordingly!"
  echo "# cp <path to your github copy>/soe-reference-architecture/soe-config.example ~/.soe-config"
  exit 1
fi

###################################################################################################
#
# Basic Provisioning Setup
#
###################################################################################################

# clone Kickstart and PXE Boot template (actually we have to dump and create)
hammer template dump --name "Satellite Kickstart Default" > "/tmp/tmp.skd"
hammer template create --file /tmp/tmp.skd --name "${ORG} Kickstart default" --organizations "${ORG}" --type provision

hammer template dump --name "Kickstart default PXELinux" > "/tmp/tmp.kdp"
hammer template create --file /tmp/tmp.kdp --name "${ORG} Kickstart default PXELinux" --organizations "${ORG}" --type PXELinux

hammer template dump --name "Boot disk iPXE - host" > "/tmp/tmp.bdp"
hammer template create --file /tmp/tmp.bdp --name "${ORG} Boot disk iPXE - host" --organizations "${ORG}" --type Bootdisk

# add operating system no matter if rhel5,6 or 7,.. to the SOE kickstart template since we follow the principal of having a single kickstart template for all OS releases
hammer os list | awk -F "|" '/RedHat/ {print $2}' | sed s'/ //' | while read RHEL_Release; do hammer template add-operatingsystem --name "${ORG} Kickstart default PXELinux" --operatingsystem "${RHEL_Release}"; done
hammer os list | awk -F "|" '/RedHat/ {print $2}' | sed s'/ //' | while read RHEL_Release; do hammer template add-operatingsystem --name "${ORG} Kickstart default" --operatingsystem "${RHEL_Release}"; done
hammer os list | awk -F "|" '/RedHat/ {print $2}' | sed s'/ //' | while read RHEL_Release; do hammer template add-operatingsystem --name "${ORG} Boot disk iPXE - host" --operatingsystem "${RHEL_Release}"; done

# create custom ptable file to import via hammer
cat > /tmp/tmp.${ORG}.ptable <<- EOF
<%#
kind: ptable
name: ${PTABLE_NAME}
oses:
- RedHat 5
- RedHat 6
- RedHat 7
%>
zerombr
clearpart --all --initlabel
part /boot --fstype ext4 --size=128 --ondisk=sda --asprimary
part pv.1 --size=1 --grow --ondisk=sda
volgroup vg_sys --pesize=32768 pv.1
logvol / --fstype ext4 --name=lv_root --vgname=vg_sys --size=2048 --fsoptions="noatime"
logvol swap --fstype swap --name=lv_swap --vgname=vg_sys --size=2048
logvol /home --fstype ext4 --name=lv_home --vgname=vg_sys --size=2048 --fsoptions="noatime,usrquota,grpquota"
logvol /tmp --fstype ext4 --name=lv_tmp --vgname=vg_sys --size=1024 --fsoptions="noatime"
logvol /usr --fstype ext4 --name=lv_usr --vgname=vg_sys --size=4096 --fsoptions="noatime"
logvol /var --fstype ext4 --name=lv_var --vgname=vg_sys --size=3072 --fsoptions="noatime"
logvol /var/log/ --fstype ext4 --name=lv_log --vgname=vg_sys --size=8192 --fsoptions="noatime"
logvol /var/log/audit --fstype ext4 --name=lv_audit --vgname=vg_sys --size=256 --fsoptions="noatime"
EOF

# create acme ptable
# http://projects.theforeman.org/projects/foreman/wiki/Dynamic_disk_partitioning
hammer partition-table create --name ${PTABLE_NAME} --os-family "Redhat" --file /tmp/tmp.${ORG}.ptable

# bring templates and partition table together to operating systems
# first we change the root passwort hash from md5 to sha512 (more secure)
hammer os list | awk -F "|" '/RedHat/ {print $2}' | sed s'/ //' | while read RHEL_Release
do
  hammer os update --title "${RHEL_Release}" --password-hash SHA512
  hammer os add-architecture --title "${RHEL_Release}" --architecture x86_64
  hammer os add-ptable --title "${RHEL_Release}" --partition-table "${PTABLE_NAME}"
  hammer os add-config-template --title "${RHEL_Release}" --config-template "${ORG} Kickstart default PXELinux"
  hammer os add-config-template --title "${RHEL_Release}" --config-template "${ORG} Kickstart default"
  hammer os add-config-template --title "${RHEL_Release}" --config-template "${ORG} Boot disk iPXE - host"
done

# add config template as default - currently only possible with id
hammer os list | awk -F "|" '/[[:digit:]]/ {print $1}' | while read RHEL_major_id
do
  hammer template list | awk -F "|" "/${ORG}/ {print \$1}" | while read template_id
  do
    hammer os set-default-template --id ${RHEL_major_id} --config-template-id ${template_id}
    hammer template update --id ${template_id} --organizations "${ORG}"
  done
done

# update domain with organization (domain should have been created during katello-installer run)
# search for proxy with DNS capability, if dns is used add the capsule to the domain
hammer proxy list | awk -F "|" '/DNS/ {print $2}' | sed s'/ //' | while read Proxy
do
  if [[ -n $Proxy ]]; then
    hammer domain update --name "${DOMAIN}" --dns "${Proxy}"
  fi
done
hammer domain update --name "${DOMAIN}" --organizations "${ORG}"
hammer domain update --name "${DOMAIN}" --locations "${LOCATION}"

# create location
for LOC in ${LOCATIONS}
do
  hammer location create --name "${LOC}"
done

# create subnet
# we assume that TFTP, DHCP and DNS capability is being used from the satellite capsule server.
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
--to "${SUBNET_IPAM_END}"

hammer proxy list | awk -F "|" '/DNS/ {print $1}' | while read DNSProxyID
do
  if [[ -n "$DNSProxyID" ]]; then
    hammer subnet update --name "${DOMAIN}" --dns-id "${DNSProxyID}"
  fi
done

hammer proxy list | awk -F "|" '/DHCP/ {print $1}' | while read DHCPProxyID
do
  if [[ -n "$DHCPProxyID" ]]; then
    hammer subnet update --name "${DOMAIN}" --dhcp-id "${DHCPProxyID}" --ipam "DHCP"
  else
    hammer subnet update --name "${DOMAIN}" --ipam "Internal DB"
  fi
done

hammer proxy list | awk -F "|" '/TFTP/ {print $1}' | while read TFTPProxyID
do
  if [[ -n $TFTPProxyID ]]; then
    hammer subnet update --name "${DOMAIN}" --tftp-id ${TFTPProxyID}
  fi
done

if [[ -n ${DNS_SECONDARY} ]]; then
  hammer subnet update --name "${DOMAIN}" --dns-secondary ${DNS_SECONDARY}
fi

# create host collections
if [ ${RHEL6_ENABLED} -ne 0 ]; then
  hammer host-collection create --name "6Server" --organization "${ORG}"
fi

hammer host-collection create --name "7Server" --organization "${ORG}"
hammer host-collection create --name "RHEL" --organization "${ORG}"

for arch in ${ARCH}
do
  hammer host-collection create --name ${arch} --organization "${ORG}"
done

hammer lifecycle-environment list --organization "${ORG}" | awk -F "|" '/[[:digit:]]/ {print $2}' | sed s'/ //' | while read LC_ENV
do
  hammer host-collection create --name $(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]') --organization "${ORG}"
done

# activation keys are create during host group creation

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

# create host groups
#create the second level of the host group (RHEL Core Build)
PuppetProxy=$(hammer proxy list | awk -F "|" '/Puppe/ {print $2;exit}' | xargs)

hammer lifecycle-environment list --organization "${ORG}" | awk -F "|" '/[[:digit:]]/ {print $2}' | sed s'/ //' | while read LC_ENV
do

  #create the top level of the host group (lifecycle environment)
  hammer hostgroup create --name ${LC_ENV}

    OS=$(hammer os list | awk -F '|' '/RedHat 7/ {print $2;exit}' | xargs)
    for arch in "${ARCH}"
    do
#      #there is no i386 for rhel7 so we have to skip creating anything for it
      if [[ $arch != i386 ]]; then
#
        #create activation key while we create the according hostgroup
        hammer activation-key create \
          --organization "${ORG}" \
          --name $(echo "act-${LC_ENV}-os-rhel-7Server-${arch}" | tr '[[:upper:]' '[[:lower:]]') \
          --lifecycle-environment "${LC_ENV}"
          #--content-view "cv-os-rhel-7Server" \

        hammer hostgroup create --name "RHEL-7Server-${arch}" \
          --medium "${ORG}/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_7_Server_Kickstart_${arch}_7Server" \
          --parent "${LC_ENV}" \
          --architecture "${arch}" \
          --operatingsystem "${OS}" \
          --partition-table "${PTABLE_NAME}" \
          --subnet "${DOMAIN}" \
          --domain "${DOMAIN}" \
          --lifecycle-environment "${LC_ENV}" \
          --organizations "${ORG}" \
          --locations "${LOCATIONS}"
          #--content-view "cv-os-rhel-7Server"
      fi

      if [ ${RHEL6_ENABLED} -ne 0 ]; then

        hammer activation-key create \
          --name $(echo "act-${LC_ENV}-os-rhel-6Server-${arch}" | tr '[[:upper:]' '[[:lower:]]') \
          --content-view "cv-os-rhel-6Server" \
          --lifecycle-environment "${LC_ENV}" \
          --organization "${ORG}"

        OS=$(hammer os list | awk -F '|' '/RedHat 6/ {print $2;exit}' | xargs)

        hammer hostgroup create --name "RHEL-6Server-${arch}" \
          --parent "${LC_ENV}" \
          --architecture "${arch}" \
          --operatingsystem "${OS}" \
          --medium "${ORG}/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_6_Server_Kickstart_${arch}_6Server" \
          --partition-table "${PTABLE_NAME}" \
          --subnet "${DOMAIN}" \
          --domain "${DOMAIN}" \
          --lifecycle-environment "${LC_ENV}" \
          --content-view "cv-os-rhel-6Server" \
          --puppet-proxy "${PuppetProxy}" \
          --puppet-ca-proxy "${PuppetProxy}" \
          --organizations "${ORG}" \
          --locations "${LOCATIONS}"
      fi

    done
done


########### DEPLOYMENT ###############

# add hostgroups & activation keys for the APPS we want to deploy
# Applications will only exist in non Library ENV

declare -A RHEL7APPS
RHEL7APPS=( ["DEV"]='["Infrastructure Services"]="IdM,Git Server,Backup Server,Monitoring Server,RHEV,Docker Host,Core Build,Intranet"'\
            ["QA"]='["Infrastructure Services"]="IdM,Git Server,Backup Server,Monitoring Server,RHEV,Docker Host,Core Build,Intranet"'\
            ["PROD"]='["Infrastructure Services"]="IdM,Git Server,Backup Server,Monitoring Server,RHEV,Docker Host,Core Build,Intranet"'\
            ["Shop-DEV"]='[Ticketshop]="Ticketmonster JEE APP,JBoss EAP,MariaDB"'\
            ["Shop-QA"]='[Ticketshop]="Ticketmonster JEE APP,JBoss EAP,MariaDB"'\
            ["Shop-PROD"]='[Ticketshop]="Ticketmonster JEE APP,JBoss EAP,MariaDB"'\
            ["Web-DEV"]='["ACME Website"]="Content,Wordpress,MariaDB"'\
            ["Web-QA"]='["ACME Website"]="Content,Wordpress,MariaDB"'\
            ["Web-UAT"]='["ACME Website"]="Content,Wordpress,MariaDB"'\
            ["Web-PROD"]='["ACME Website"]="Content,Wordpress,MariaDB"'\
          )

for STAGE in "${!RHEL7APPS[@]}"
do
  LC_ENV=${STAGE}
  OS=$(hammer os list | awk -F '|' '/RedHat 7/ {print $2;exit}' | xargs)
  for arch in ${ARCH}
  do
    if [[ ${arch} != i386 ]]; then

      declare -A TOPLVLHG
      eval TOPLVLHG=( "${RHEL7APPS[$STAGE]}" )

      TMPIFS=$IFS
      IFS=","
      for KEY in ${!TOPLVLHG[@]}
      do
        if [[ $KEY = "Infrastructure Services" ]]; then
          TYPE="infra"
          KEY_LABEL="infra"
        else
          TYPE="biz"
          KEY_LABEL="${KEY}"
        fi

        hammer host-collection create --name "${KEY}" --organization "${ORG}"

        hammer activation-key create \
        --name $(echo "act-${LC_ENV}-${KEY_LABEL}-${arch}" | sed s'/ /_/g' | tr '[[:upper:]' '[[:lower:]]') \
        --lifecycle-environment "${LC_ENV}" \
        --organization "${ORG}"
        #--content-view

        ParentID=$(hammer hostgroup list --per-page 999| awk -F"|" "\$3 = /[[:space:]]${LC_ENV}\/RHEL-7Server-${arch}[[:space:]]/ {print \$1}")

        #create toplevel APP
        hammer hostgroup create --name "${KEY}" \
        --parent-id "${ParentID}" \
        --architecture "${arch}" \
        --operatingsystem "${OS}" \
        --medium "${ORG}/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_7_Server_Kickstart_${arch}_7Server" \
        --partition-table "${PTABLE_NAME}" \
        --subnet "${DOMAIN}" \
        --domain "${DOMAIN}" \
        --lifecycle-environment "${LC_ENV}" \
        --puppet-proxy "${PuppetProxy}" \
        --puppet-ca-proxy "${PuppetProxy}" \
        --organizations "${ORG}" \
        --locations "${LOCATIONS}"
        #--content-view

        for APP in ${TOPLVLHG[$KEY]}
        do
          ParentID=$(hammer hostgroup list --per-page 999| awk -F"|" "\$3 = /[[:space:]]${LC_ENV}\/RHEL-7Server-${arch}\/${KEY}[[:space:]]/ {print \$1}")

          hammer hostgroup create --name "${APP}" \
          --parent-id "${ParentID}" \
          --architecture "${arch}" \
          --operatingsystem "${OS}" \
          --medium "${ORG}/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_7_Server_Kickstart_${arch}_7Server" \
          --partition-table "${PTABLE_NAME}" \
          --subnet "${DOMAIN}" \
          --domain "${DOMAIN}" \
          --lifecycle-environment "${LC_ENV}" \
          --puppet-proxy "${PuppetProxy}" \
          --puppet-ca-proxy "${PuppetProxy}" \
          --organizations "${ORG}" \
          --locations "${LOCATIONS}"
          #--content-view

          hammer host-collection create --name "${APP}" --organization "${ORG}"

          hammer activation-key create \
          --name $(echo "act-${LC_ENV}-${KEY_LABEL}-${APP}-${arch}" | tr '[[:upper:]' '[[:lower:]]' | sed s'/ /_/g') \
          --lifecycle-environment "${LC_ENV}" \
          --organization "${ORG}"
          #--content-view
        done
        IFS=$TMPIFS
      done
    fi
  done
done
