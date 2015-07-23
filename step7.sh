#!/bin/bash
#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
#
# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

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

# create location
for LOC in ${LOCATIONS}
do
  hammer location create --name "${LOC}"
  hammer location add-organization --name "${LOC}" --organization "${ORG}"
done

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
cat > /tmp/tmp.${ORG}.ptable <<- EOC
'
<%#
kind: ptable
name: ptable-ACME-os-rhel-server
oses:
- RedHat 5
- RedHat 6
- RedHat 7
%>
#Dynamic
PRI_DISK=$(awk '/[v|s]da|c0d0/ {print $4 ;exit}' /proc/partitions)
grep -E -q '[v|s]db|c0d1' /proc/partitions  &&  SEC_DISK=$(awk '/[v|s]db/ {print $4 ;exit}' /proc/partitions)

cat <<EOF > /tmp/diskpart.cfg
zerombr
clearpart --all --initlabel
part /boot --fstype ext4 --size=512 --ondisk=${PRI_DISK} --asprimary
part pv.1 --size=1 --grow --ondisk=${PRI_DISK}
volgroup vg_sys --pesize=32768 pv.1
logvol / --fstype ext4 --name=lv_root --vgname=vg_sys --size=2048 --fsoptions="noatime"
logvol swap --fstype swap --name=lv_swap --vgname=vg_sys --size=2048
logvol /home --fstype ext4 --name=lv_home --vgname=vg_sys --size=2048 --fsoptions="noatime,usrquota,grpquota"
logvol /tmp --fstype ext4 --name=lv_tmp --vgname=vg_sys --size=1024 --fsoptions="noatime"
logvol /usr --fstype ext4 --name=lv_usr --vgname=vg_sys --size=4096 --fsoptions="noatime"
logvol /var --fstype ext4 --name=lv_var --vgname=vg_sys --size=2048 --fsoptions="noatime"
logvol /var/log/ --fstype ext4 --name=lv_log --vgname=vg_sys --size=4096 --fsoptions="noatime"
logvol /var/log/audit --fstype ext4 --name=lv_audit --vgname=vg_sys --size=256 --fsoptions="noatime"
EOF
'
EOC

# create acme ptable
# http://projects.theforeman.org/projects/foreman/wiki/Dynamic_disk_partitioning
hammer partition-table create --name $(echo ${PTABLE_NAME} | tr '[[:upper:]' '[[:lower:]]') --os-family "Redhat" --file /tmp/tmp.${ORG}.ptable

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
    hammer template update --id ${template_id} --organizations "${ORG}" --locations "${LOCATIONS}"
  done
done

ORG="ACME"
LOCATIONS="munich,munich-dmz"
hammer lifecycle-environment list --organization "${ORG}" | awk -F "|" '/[[:digit:]]/ {print $2}' | sed s'/ //' | while read LC_ENV
do
  if [[ ${LC_ENV} == "Library" ]]; then
    continue
  fi
  hammer hostgroup create --name $( echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]' ) \
    --organizations "${ORG}" \
    --locations "${LOCATIONS}" \
    --lifecycle-environment "${LC_ENV}" \
    --puppet-ca-proxy-id 1 \
    --puppet-proxy-id 1 \
    --content-source-id 1
done

###################################
#  create host collections        #
###################################

  ORG="ACME"
  for HC in 6Server 7Server RHEL infra biz gitserver containerhost capsule loghost acmeweb acmeweb-frontend acmeweb-backend x86_64
  do
    hammer host-collection create --name ${HC} --organization "${ORG}"
  done

  hammer lifecycle-environment list --organization "${ORG}" | awk -F "|" '/[[:digit:]]/ {print $2}' | sed s'/ //' | while read LC_ENV
  do
    hammer host-collection create --name $(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]') --organization "${ORG}"
  done

#RHEL-7SERVER-X86_64
MAJOR="7"
OS=$(hammer --output csv os list | awk -F "," "/RedHat ${MAJOR}/ {print \$2;exit}")
ARCH="x86_64"
ORG="ACME"
LOCATIONS="munich,munich-dmz"
PTABLE_NAME="ptable-acme-os-rhel-server"
DOMAIN="example.com"
hammer lifecycle-environment list --organization "${ORG}" | awk -F "|" '/[[:digit:]]/ {print $2}' | sed s'/ //' | while read LC_ENV
do
  if [[ ${LC_ENV} == "Library" ]]; then
    continue
  fi
  LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
  ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}$/) {print \$1}")
  hammer hostgroup create --name "rhel-${MAJOR}server-${ARCH}" \
    --medium "${ORG}/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_${MAJOR}_Server_Kickstart_${ARCH}_${MAJOR}Server" \
    --parent-id ${ParentID} \
    --architecture "${ARCH}" \
    --operatingsystem "${OS}" \
    --partition-table "${PTABLE_NAME}" \
    --subnet "${DOMAIN}" \
    --domain "${DOMAIN}" \
    --organizations "${ORG}" \
    --locations "${LOCATIONS}" \
    --content-view "cv-os-rhel-${MAJOR}Server" \
    --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," ""/KT_${ORG}_${LC_ENV}_cv_os_rhel_${MAJOR}Server/ {print $1}"")

  HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}/) {print \$1}")
  hammer hostgroup set-parameter \
    --hostgroup-id "${HgID}" \
    --name "kt_activation_keys" \
    --value "act-${LC_ENV_LOWER}-os-rhel-${MAJOR}server-${ARCH}"
  done

  #RHEL-7SERVER-X86_64
  MAJOR="6"
  OS=$(hammer --output csv os list | awk -F "," "/RedHat ${MAJOR}/ {print \$2;exit}")
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich,munich-dmz"
  PTABLE_NAME="ptable-acme-os-rhel-server"
  DOMAIN="example.com"
  hammer lifecycle-environment list --organization "${ORG}" | awk -F "|" '/[[:digit:]]/ {print $2}' | sed s'/ //' | while read LC_ENV
  do
    if [[ ${LC_ENV} == "Library" ]]; then
      continue
    fi
    LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}$/) {print \$1}")
    hammer hostgroup create --name "rhel-${MAJOR}server-${ARCH}" \
      --medium "${ORG}/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_${MAJOR}_Server_Kickstart_${ARCH}_${MAJOR}_${MAJOR}" \
      --parent-id ${ParentID} \
      --architecture "${ARCH}" \
      --operatingsystem "${OS}" \
      --partition-table "${PTABLE_NAME}" \
      --subnet "${DOMAIN}" \
      --domain "${DOMAIN}" \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "cv-os-rhel-${MAJOR}Server" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_cv_os_rhel_${MAJOR}Server/ {print \$1}")

    HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}/) {print \$1}")
    hammer hostgroup set-parameter \
      --hostgroup-id "${HgID}" \
      --name "kt_activation_keys" \
      --value "act-${LC_ENV_LOWER}-os-rhel-${MAJOR}server-${ARCH}"
    done

  #RHEL-7SERVER-X86_64/INFRA
  MAJOR="7"
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich,munich-dmz"
  LC_ENV="dev qa prod"
  for LC_ENV_LOWER in ${LC_ENV}
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "infra" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}"
  done

  #RHEL-6SERVER-X86_64/INFRA
  MAJOR="6"
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich,munich-dmz,boston"
  LC_ENV="dev qa prod"
  for LC_ENV_LOWER in ${LC_ENV}
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "infra" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}"
  done

  #LOGHOST
  MAJOR="6"
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich,munich-dmz"
  LC_ENV="dev qa prod"
  for LC_ENV_LOWER in ${LC_ENV}
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "loghost" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "cv-os-rhel-6Server" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_cv_os_rhel_${MAJOR}Server/ {print \$1}") \

     HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/loghost$/) {print \$1}")
     hammer hostgroup set-parameter \
       --hostgroup-id "${HgID}" \
       --name "kt_activation_keys" \
       --value "act-${LC_ENV_LOWER}-infra-loghost-x86_64"
  done

  #CAPSULE
  MAJOR="7"
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich"
  LC_ENV="dev qa prod"
  for LC_ENV_LOWER in ${LC_ENV}
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "capsule" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "ccv-infra-capsule" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_ccv_infra_capsule/ {print \$1}")

     HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/capsule$/) {print \$1}")
     hammer hostgroup set-parameter \
       --hostgroup-id "${HgID}" \
       --name "kt_activation_keys" \
       --value "act-${LC_ENV_LOWER}-infra-capsule-x86_64"
  done

  #GITSERVER
  MAJOR="7"
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich,munich-dmz"
  LC_ENV="dev qa prod"
  for LC_ENV_LOWER in ${LC_ENV}
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "gitserver" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "ccv-infra-gitserver" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_ccv_infra_gitserver/ {print \$1}") \
      --puppet-classes 'git::server'

     HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/gitserver$/) {print \$1}")
     hammer hostgroup set-parameter \
       --hostgroup-id "${HgID}" \
       --name "kt_activation_keys" \
       --value "act-${LC_ENV_LOWER}-infra-gitserver-x86_64"
   done

 #containerhost
 MAJOR="7"
 ARCH="x86_64"
 ORG="ACME"
 LOCATIONS="munich,munich-dmz"
 LC_ENV="dev qa prod"
 for LC_ENV_LOWER in ${LC_ENV}
 do
   ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
   hammer hostgroup create --name "containerhost" \
     --parent-id ${ParentID} \
     --organizations "${ORG}" \
     --locations "${LOCATIONS}" \
     --content-view "ccv-infra-containerhost" \
     --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_ccv_infra_containerhost/ {print \$1}") \
     --puppet-classes 'docker'

    HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/containerhost$/) {print \$1}")
    hammer hostgroup set-parameter \
      --hostgroup-id "${HgID}" \
      --name "kt_activation_keys" \
      --value "act-${LC_ENV_LOWER}-infra-containerhost-x86_64"
  done

  #ACMEWEB
  MAJOR="7"
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich,munich-dmz,boston"
  LC_ENV="web-dev web-qa web-uat web-prod"
  for LC_ENV_LOWER in ${LC_ENV}
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "acmeweb" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "ccv-biz-acmeweb" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_ccv_biz_acmeweb/ {print \$1}")
  done

  #ACMEB-FRONTEND
  MAJOR="7"
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich,munich-dmz,boston"
  LC_ENV="web-dev web-qa web-uat web-prod"
  for LC_ENV_LOWER in ${LC_ENV}
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/acmeweb$/) {print \$1}")
    hammer hostgroup create --name "frontend" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --puppet-classes 'acmeweb::frontend'

      HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/acmeweb\/frontend$/) {print \$1}")
      hammer hostgroup set-parameter \
        --hostgroup-id "${HgID}" \
        --name "kt_activation_keys" \
        --value "act-${LC_ENV_LOWER}-biz-acmeweb-x86_64"
  done

  #ACMEWEB-BACKEND
  MAJOR="7"
  ARCH="x86_64"
  ORG="ACME"
  LOCATIONS="munich,munich-dmz,boston"
  LC_ENV="web-dev web-qa web-uat web-prod"
  for LC_ENV_LOWER in ${LC_ENV}
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/acmeweb$/) {print \$1}")
    hammer hostgroup create --name "backend" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --puppet-classes 'acmeweb::backend'

      HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/acmeweb\/backend$/) {print \$1}")
      hammer hostgroup set-parameter \
        --hostgroup-id "${HgID}" \
        --name "kt_activation_keys" \
        --value "act-${LC_ENV_LOWER}-biz-acmeweb-x86_64"
  done

  #rhel-7server
  ORG="ACME"
  ARCH="x86-64"
  TYPE="os"
  ROLE="rhel-7server"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENV}
  do
      LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
      LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

      hammer activation-key create \
            --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
            --content-view "cv-os-rhel-7Server" \
            --lifecycle-environment "${LC_ENV}" \
            --organization "${ORG}"

      SubIDs="${SubRHEL} ${SubZabbix} ${SubACME}"
      for SubID in ${SubIDs}
      do
        hammer activation-key add-subscription \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --subscription-id "${SubID}" \
              --organization "${ORG}"
      done

      HostCollection="RHEL 7Server x86_64 ${LC_ENV_UPPER}"
      for COLLECTION in ${HostCollection}
      do
        hammer activation-key add-host-collection \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --host-collection "${COLLECTION}" \
              --organization "${ORG}"
      done

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-7-server-rh-common-rpms"
      for CLABEL in ${ContentLabels}
      do
        hammer activation-key content-override \
              --content-label ${CLABEL} \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --organization "${ORG}" \
              --value "1"
      done
  done

  #rhel-6server
  ORG="ACME"
  ARCH="x86-64"
  TYPE="os"
  ROLE="rhel-6server"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENV}
  do
      LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
      LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

      hammer activation-key create \
            --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
            --content-view "cv-os-rhel-6Server" \
            --lifecycle-environment "${LC_ENV}" \
            --organization "${ORG}"

      SubIDs="${SubRHEL} ${SubZabbix} ${SubACME}"
      for SubID in ${SubIDs}
      do
        hammer activation-key add-subscription \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --subscription-id "${SubID}" \
              --organization "${ORG}"
      done

      HostCollection="RHEL 6Server x86_64 ${LC_ENV_UPPER}"
      for COLLECTION in ${HostCollection}
      do
        hammer activation-key add-host-collection \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --host-collection "${COLLECTION}" \
              --organization "${ORG}"
      done

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL6-x86_64 rhel-6-server-rpms rhel-6-server-rh-common-rpms"
      for CLABEL in ${ContentLabels}
      do
        hammer activation-key content-override \
              --content-label ${CLABEL} \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --organization "${ORG}" \
              --value "1"
      done
  done

  #CONTAINERHOST
  ORG="ACME"
  ARCH="x86-64"
  TYPE="infra"
  ROLE="containerhost"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENV}
  do
      LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
      LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

      hammer activation-key create \
            --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
            --content-view "ccv-infra-containerhost" \
            --lifecycle-environment "${LC_ENV}" \
            --organization "${ORG}"

      SubIDs="${SubRHEL} ${SubZabbix} ${SubACME}"
      for SubID in ${SubIDs}
      do
        hammer activation-key add-subscription \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --subscription-id "${SubID}" \
              --organization "${ORG}"
      done

      HostCollection="containerhost RHEL 7Server x86_64 ${LC_ENV_UPPER}"
      for COLLECTION in ${HostCollection}
      do
        hammer activation-key add-host-collection \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --host-collection "${COLLECTION}" \
              --organization "${ORG}"
      done

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-7-server-rh-common-rpms rhel-7-server-extras-rpms"
      for CLABEL in ${ContentLabels}
      do
        hammer activation-key content-override \
              --content-label ${CLABEL} \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --organization "${ORG}" \
              --value "1"
      done
  done

  #CAPSULE
  ORG="ACME"
  ARCH="x86-64"
  TYPE="infra"
  ROLE="capsule"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  SubCapsule=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Satellite Capsule Server$/) {print \$8}")
  for LC_ENV in ${LC_ENV}
  do
      LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
      LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

      hammer activation-key create \
            --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
            --content-view "ccv-infra-capsule" \
            --lifecycle-environment "${LC_ENV}" \
            --organization "${ORG}"

      SubIDs="${SubRHEL} ${SubZabbix} ${SubACME} ${SubCapsule}"
      for SubID in ${SubIDs}
      do
        hammer activation-key add-subscription \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --subscription-id "${SubID}" \
              --organization "${ORG}"
      done

      HostCollection="capsule RHEL 7Server x86_64 ${LC_ENV_UPPER}"
      for COLLECTION in ${HostCollection}
      do
        hammer activation-key add-host-collection \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --host-collection "${COLLECTION}" \
              --organization "${ORG}"
      done

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-server-7-satellite-capsule-6-beta-rpms"
      for CLABEL in ${ContentLabels}
      do
        hammer activation-key content-override \
              --content-label ${CLABEL} \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --organization "${ORG}" \
              --value "1"
      done
  done

  #LOGHOST
  ORG="ACME"
  ARCH="x86-64"
  TYPE="infra"
  ROLE="loghost"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENV}
  do
      LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
      LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

      hammer activation-key create \
            --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
            --content-view "cv-os-rhel-6Server" \
            --lifecycle-environment "${LC_ENV}" \
            --organization "${ORG}"

      SubIDs="${SubRHEL} ${SubZabbix} ${SubACME}"
      for SubID in ${SubIDs}
      do
        hammer activation-key add-subscription \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --subscription-id "${SubID}" \
              --organization "${ORG}"
      done

      HostCollection="loghost RHEL 6Server x86_64 ${LC_ENV_UPPER}"
      for COLLECTION in ${HostCollection}
      do
        hammer activation-key add-host-collection \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --host-collection "${COLLECTION}" \
              --organization "${ORG}"
      done

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL6-x86_64 rhel-6-server-rpms rhel-6-server-rh-common-rpms"
      for CLABEL in ${ContentLabels}
      do
        hammer activation-key content-override \
              --content-label ${CLABEL} \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --organization "${ORG}" \
              --value "1"
      done
  done

  #GITSERVER
  ORG="ACME"
  ARCH="x86-64"
  TYPE="infra"
  ROLE="gitserver"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENV}
  do
      LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
      LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

      hammer activation-key create \
            --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
            --content-view "ccv-infra-gitserver" \
            --lifecycle-environment "${LC_ENV}" \
            --organization "${ORG}"

      SubIDs="${SubRHEL} ${SubZabbix} ${SubACME}"
      for SubID in ${SubIDs}
      do
        hammer activation-key add-subscription \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --subscription-id "${SubID}" \
              --organization "${ORG}"
      done

      HostCollection="gitserver RHEL 7Server x86_64 ${LC_ENV_UPPER}"
      for COLLECTION in ${HostCollection}
      do
        hammer activation-key add-host-collection \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --host-collection "${COLLECTION}" \
              --organization "${ORG}"
      done

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-7-server-rh-common-rpms rhel-server-rhscl-7-rpms"
      for CLABEL in ${ContentLabels}
      do
        hammer activation-key content-override \
              --content-label ${CLABEL} \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --organization "${ORG}" \
              --value "1"
      done
  done

  #ACMEWEB-FRONTEND
  ORG="ACME"
  ARCH="x86-64"
  TYPE="biz"
  ROLE="acmeweb-frontend"
  LC_ENVS="Web-DEV Web-QA Web-UAT Web-PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  SubEPEL7-APP=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^EPEL7-APP$/) {print \$8}")
  for LC_ENV in ${LC_ENV}
  do
      LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
      LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

      hammer activation-key create \
            --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
            --content-view "ccv-biz-acmeweb" \
            --lifecycle-environment "${LC_ENV}" \
            --organization "${ORG}"

      SubIDs="${SubRHEL} ${SubZabbix} ${SubACME} ${SubEPEL7-APP}"
      for SubID in ${SubIDs}
      do
        hammer activation-key add-subscription \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --subscription-id "${SubID}" \
              --organization "${ORG}"
      done

      HostCollection="acmeweb acmeweb-frontend RHEL 7Server x86_64 ${LC_ENV_UPPER}"
      for COLLECTION in ${HostCollection}
      do
        hammer activation-key add-host-collection \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --host-collection "${COLLECTION}" \
              --organization "${ORG}"
      done

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-7-server-rh-common-rpms ACME_EPEL7-APP_EPEL7-APP-x86_64"
      for CLABEL in ${ContentLabels}
      do
        hammer activation-key content-override \
              --content-label ${CLABEL} \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --organization "${ORG}" \
              --value "1"
      done
    done


    #ACMEWEB-BACKEND
    ORG="ACME"
    ARCH="x86-64"
    TYPE="biz"
    ROLE="acmeweb-backend"
    LC_ENVS="Web-DEV Web-QA Web-UAT Web-PROD"
    SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
    SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
    SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
    SubEPEL7-APP=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^EPEL7-APP$/) {print \$8}")
    for LC_ENV in ${LC_ENV}
    do
        LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
        LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

        hammer activation-key create \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --content-view "ccv-biz-acmeweb" \
              --lifecycle-environment "${LC_ENV}" \
              --organization "${ORG}"

        SubIDs="${SubRHEL} ${SubZabbix} ${SubACME} ${SubEPEL7-APP}"
        for SubID in ${SubIDs}
        do
          hammer activation-key add-subscription \
                --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
                --subscription-id "${SubID}" \
                --organization "${ORG}"
        done

        HostCollection="acmeweb acmeweb-backend RHEL 7Server x86_64 ${LC_ENV_UPPER}"
        for COLLECTION in ${HostCollection}
        do
          hammer activation-key add-host-collection \
                --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
                --host-collection "${COLLECTION}" \
                --organization "${ORG}"
        done
        ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-7-server-rh-common-rpms ACME_EPEL7-APP_EPEL7-APP-x86_64"
        for CLABEL in ${ContentLabels}
        do
          hammer activation-key content-override \
                --content-label ${CLABEL} \
                --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
                --organization "${ORG}" \
                --value "1"
        done
      done

