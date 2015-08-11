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

DIR="$PWD"
source "${DIR}/common.sh"

#create global parameters
hammer global-parameter set --name "firewall" --value "--disabled"
hammer global-parameter set --name "selinux" --value "--permissive"

#create $ORG Kickstart Default template
hammer template dump --name "Satellite Kickstart Default" > "/tmp/tmp.skd"

sed -i "s/lang.*/lang <%= @host.params['language'] %>/" /tmp/tmp.skd
sed -i "s/selinux.*/selinux <%= @host.params['selinux'] %>/" /tmp/tmp.skd
sed -i "s/firewall.*/firewall firewall <%= @host.params['firewall'] %>/" /tmp/tmp.skd

hammer template create \
     --file /tmp/tmp.skd \
     --name "${ORG} Kickstart default" \
     --organizations "${ORG}" \
     --type provision

#ptable
cat > /tmp/tmp.ptable-${ORG}-os-rhel-server.ptable <<- EOC
'#Dynamic

<% if @host.operatingsystem.major.to_i > 6 %>
  <% fstype = "xfs" %>
<% else %>
 <% fstype = "ext4" %>
<% end %>

PRI_DISK=$(awk '/[v|s]da|c0d0/ {print $4 ;exit}' /proc/partitions)
grep -E -q '[v|s]db|c1d1' /proc/partitions  &&  SEC_DISK=$(awk '/[v|s]db|c1d1/ {print $4 ;exit}' /proc/partitions)
grep -E -q '[v|s]db1|c1d1p1' /proc/partitions  &&  EXISTING="true"

echo zerombr >> /tmp/diskpart.cfg
echo clearpart --drives ${PRI_DISK} --all --initlabel >> /tmp/diskpart.cfg

echo part /boot --fstype <%= fstype %> --size=512 --ondisk=${PRI_DISK} --asprimary >> /tmp/diskpart.cfg
echo part pv.65 --size=1 --grow --ondisk=${PRI_DISK} >> /tmp/diskpart.cfg
echo volgroup vg_sys --pesize=32768 pv.65 >> /tmp/diskpart.cfg
<% if @host.params['ptable'] %>
  <%=  snippet "ptable-acme-#{@host.params['ptable']}" %>
<% end %>
echo logvol / --fstype <%= fstype %> --name=lv_root --vgname=vg_sys --size=2048 --fsoptions="noatime" >> /tmp/diskpart.cfg
echo logvol swap --fstype swap --name=lv_swap --vgname=vg_sys --size=2048 >> /tmp/diskpart.cfg
echo logvol /home --fstype <%= fstype %> --name=lv_home --vgname=vg_sys --size=2048 --fsoptions="noatime,usrquota,grpquota" >> /tmp/diskpart.cfg
echo logvol /tmp --fstype <%= fstype %> --name=lv_tmp --vgname=vg_sys --size=1024 --fsoptions="noatime" >> /tmp/diskpart.cfg
echo logvol /usr --fstype <%= fstype %> --name=lv_usr --vgname=vg_sys --size=2048 --fsoptions="noatime">> /tmp/diskpart.cfg
echo logvol /var --fstype<%= fstype %> --name=lv_var --vgname=vg_sys --size=2048 --fsoptions="noatime" >> /tmp/diskpart.cfg
echo logvol /var/log/ --fstype <%= fstype %> --name=lv_log --vgname=vg_sys --size=2048 --fsoptions="noatime" >> /tmp/diskpart.cfg
echo logvol /var/log/audit --fstype <%= fstype %> --name=lv_audit --vgname=vg_sys --size=256 --fsoptions="noatime" >> /tmp/diskpart.cfg'
EOC

hammer partition-table create --name ptable-acme-os-rhel-server --os-family "Redhat" --file /tmp/tmp.ptable-${ORG}-os-rhel-server.ptable

#nested ptable
cat > /tmp/tmp.ptable-acme-git.ptable <<- EOC
<% if @host.operatingsystem.major.to_i > 6 %>
  <% fstype =  "xfs" %>
<% else %>
 <% fstype = "ext4" %>
<% end %>
if [[ -z ${EXISTING} ]]; then
echo volgroup vg_data --pesize=32768 pv.130 >> /tmp/diskpart.cfg
echo part pv.130 --fstype="lvmpv" --size=1 --grow --ondisk=${SEC_DISK} >> /tmp/diskpart.cfg
echo logvol /srv/git --fstype <%= fstype %> --name=lv_git --vgname=vg_data --size=1 --grow --fsoptions="noatime" >> /tmp/diskpart.cfg
elif [[ -n ${SEC_DISK} ]]; then
echo logvol /srv/git --fstype <%= fstype %> --name=lv_git --vgname=vg_data --size=1 --grow --fsoptions="noatime" --noformat >> /tmp/diskpart.cfg
fi
EOC

hammer partition-table create --name ptable-acme-git --os-family "Redhat" --file /tmp/tmp.ptable-acme-git.ptable

#Add Operating System Templates
hammer os list | awk -F "|" '/RedHat/ {print $2}' | sed s'/ //' | while read RHEL_Release
    do
       hammer template add-operatingsystem \
            --name "${ORG} Kickstart default" \
            --operatingsystem "${RHEL_Release}"

       hammer template add-operatingsystem \
            --name "Kickstart default PXELinux" \
            --operatingsystem "${RHEL_Release}"

       hammer template add-operatingsystem \
           --name "Boot disk iPXE - host" \
           --operatingsystem "${RHEL_Release}"

       hammer template add-operatingsystem \
            --name "Satellite Kickstart Default User Data" \
            --operatingsystem "${RHEL_Release}"
    done

#Assign Architecture, Templates, and Partition Tables to ORG
hammer os list | awk -F "|" '/RedHat/ {print $2}' | sed s'/ //' | while read RHEL_Release
  do
       hammer os add-architecture --title "${RHEL_Release}" \
            --architecture ${ARCH}

       hammer os add-ptable --title "${RHEL_Release}" \
            --partition-table "ptable-acme-os-rhel-server"

       hammer os add-ptable --title "${RHEL_Release}" \
            --partition-table "Kickstart default"

       hammer os add-config-template --title "${RHEL_Release}" \
            --config-template "Kickstart default PXELinux"

       hammer os add-config-template --title "${RHEL_Release}" \
           --config-template "${ORG} Kickstart default"

       hammer os add-config-template --title "${RHEL_Release}" \
           --config-template "Boot disk iPXE - host"

       hammer os add-config-template --title "${RHEL_Release}" \
           --config-template "Satellite Kickstart Default User Data"
  done

#Add Capsule:
ProxyID=1
hammer subnet update --name "${SUBNET_NAME1}" \
  --dns-id "${ProxyID}" \
  --dhcp-id "${ProxyID}" --ipam "DHCP" \
  --tftp-id "${ProxyID}" \
  --locations "${LOCATION1}"

#Configure Domains
hammer domain update --name "${DOMAIN1}" --locations "${LOCATION1}"
hammer domain update --name "${DOMAIN2}" --locations "${LOCATION2}"
hammer domain update --name "${DOMAIN3}" --locations "${LOCATION3}"


#Configure Subnets
hammer subnet update --name "${SUBNET_NAME1}" \
         --domains "${DOMAIN1}"
hammer subnet update --name "${SUBNET_NAME2}" \
         --domains "${DOMAIN2}"
hammer subnet update --name "${SUBNET_NAME3}" \
         --domains "${DOMAIN3}"

#COMPUTE RESOURCE
hammer compute-resource update --organizations "${ORG}" --locations "${LOCATION1}" --name "${COMPUTE_NAME1}"
hammer compute-resource update --organizations "${ORG}" --locations "${LOCATION2}" --name "${COMPUTE_NAME2}"
hammer compute-resource update --organizations "${ORG}" --locations "${LOCATION3}" --name "${COMPUTE_NAME3}"

#Add Location to ORG
hammer location add-organization --name "${LOCATION1}" --organization "${ORG}"
hammer location add-organization --name "${LOCATION2}" --organization "${ORG}"
hammer location add-organization --name "${LOCATION3}" --organization "${ORG}"

#Create Host Collections
  for HC in 6Server 7Server RHEL infra biz gitserver containerhost capsule loghost acmeweb acmeweb-frontend acmeweb-backend x86_64
  do
    hammer host-collection create --name ${HC} --organization "${ORG}"
  done

  hammer lifecycle-environment list --organization "${ORG}" | awk -F "|" '/[[:digit:]]/ {print $2}' | sed s'/ //' | while read LC_ENV
  do
    hammer host-collection create --name $(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]') --organization "${ORG}"
  done

#CREATE ACTIVATION KEYS
 #rhel-7server
  TYPE="os"
  ROLE="rhel-7server"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENVS}
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

  #rhel-6server
  TYPE="os"
  ROLE="rhel-6server"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENVS}
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

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL6-x86_64 rhel-6-server-rpms rhel-server-6-satellite-capsule-6-beta-rpms"
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
  TYPE="infra"
  ROLE="containerhost"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENVS}
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

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-7-server-extras-rpms rhel-server-7-satellite-capsule-6-beta-rpms"
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
  TYPE="infra"
  ROLE="capsule"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  SubCapsule=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Satellite Capsule Server$/) {print \$8}")
  for LC_ENV in ${LC_ENVS}
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
  TYPE="infra"
  ROLE="loghost"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENVS}
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

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL6-x86_64 rhel-6-server-rpms rhel-server-6-satellite-capsule-6-beta-rpms"
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
  TYPE="infra"
  ROLE="gitserver"
  LC_ENVS="DEV QA PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  for LC_ENV in ${LC_ENVS}
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

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-server-rhscl-7-rpms rhel-server-7-satellite-capsule-6-beta-rpms"
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
  TYPE="biz"
  ROLE="acmeweb-frontend"
  LC_ENVS="Web-DEV Web-QA Web-UAT Web-PROD"
  SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
  SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
  SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
  SubEPEL7APP=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^EPEL7-APP$/) {print \$8}")
  for LC_ENV in ${LC_ENVS}
  do
      LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
      LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

      hammer activation-key create \
            --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
            --content-view "ccv-biz-acmeweb" \
            --lifecycle-environment "${LC_ENV}" \
            --organization "${ORG}"

      SubIDs="${SubRHEL} ${SubZabbix} ${SubACME} ${SubEPEL7APP}"
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

      ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms ACME_EPEL7-APP_EPEL7-APP-x86_64 rhel-server-7-satellite-capsule-6-beta-rpms"
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
    TYPE="biz"
    ROLE="acmeweb-backend"
    LC_ENVS="Web-DEV Web-QA Web-UAT Web-PROD"
    SubRHEL=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Red Hat Enterprise Linux with Smart Virtualization/) {print \$8}")
    SubZabbix=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^Zabbix-Monitoring$/) {print \$8}")
    SubACME=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^ACME$/) {print \$8}")
    SubEPEL7APP=$(hammer --csv --csv-separator '#' subscription list --per-page 9999 --organization ${ORG} | awk -F"#" "(\$1 ~ /^EPEL7-APP$/) {print \$8}")
    for LC_ENV in ${LC_ENVS}
    do
        LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
        LC_ENV_UPPER=$(echo ${LC_ENV} | tr '[[:lower:]' '[[:upper:]]')

        hammer activation-key create \
              --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
              --content-view "ccv-biz-acmeweb" \
              --lifecycle-environment "${LC_ENV}" \
              --organization "${ORG}"

        SubIDs="${SubRHEL} ${SubZabbix} ${SubACME} ${SubEPEL7APP}"
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
        ContentLabels="ACME_Zabbix-Monitoring_Zabbix-RHEL7-x86_64 rhel-7-server-rpms rhel-server-7-satellite-capsule-6-beta-rpms ACME_EPEL7-APP_EPEL7-APP-x86_64"
        for CLABEL in ${ContentLabels}
        do
          hammer activation-key content-override \
                --content-label ${CLABEL} \
                --name "act-${LC_ENV_LOWER}-${TYPE}-${ROLE}-${ARCH}" \
                --organization "${ORG}" \
                --value "1"
        done
      done

#Host GROUPS
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

MAJOR="6"
MINOR="5"
OS=$(hammer --output csv os list | awk -F "," "/RedHat ${MAJOR}/ {print \$2;exit}")
LOCATIONS="${LOCATION1},${LOCATION2}"
PTABLE_NAME="ptable-acme-os-rhel-server"
DOMAIN="${DOMAIN1}"
  for LC_ENV in DEV QA PROD
  do
    if [[ ${LC_ENV} == "Library" ]]; then
      continue
    fi
    LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}$/) {print \$1}")
    hammer hostgroup create --name "rhel-${MAJOR}server-${ARCH}" \
      --medium "${ORG}/Library/Red_Hat_Server/Red_Hat_Enterprise_Linux_${MAJOR}_Server_Kickstart_${ARCH}_${MAJOR}_${MINOR}" \
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

    HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup set-parameter \
      --hostgroup-id "${HgID}" \
      --name "kt_activation_keys" \
      --value "act-${LC_ENV_LOWER}-os-rhel-${MAJOR}server-${ARCH}"
    done


MAJOR="7"
OS=$(hammer --output csv os list | awk -F "," "/RedHat ${MAJOR}/ {print \$2;exit}")
LOCATIONS="${LOCATION1},${LOCATION2}"
PTABLE_NAME="ptable-acme-os-rhel-server"
DOMAIN="${DOMAIN1}"
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
    --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_cv_os_rhel_${MAJOR}Server/ {print \$1}")

  HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
  hammer hostgroup set-parameter \
    --hostgroup-id "${HgID}" \
    --name "kt_activation_keys" \
    --value "act-${LC_ENV_LOWER}-os-rhel-${MAJOR}server-${ARCH}"
  done


MAJOR="7"
LOCATIONS="${LOCATION1},${LOCATION2}"
  for LC_ENV_LOWER in dev qa prod
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "infra" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}"
  done

MAJOR="6"
LOCATIONS="${LOCATION1},${LOCATION2},${LOCATION3}"
  for LC_ENV_LOWER in dev qa prod
  do
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "infra" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}"
  done




#GIT
MAJOR="7"
LOCATIONS="${LOCATION1},${LOCATION2}"
  for LC_ENV in DEV QA PROD
  do
  LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/infra$/) {print \$1}")
    hammer hostgroup create --name "gitserver" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "ccv-infra-gitserver" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_ccv_infra_gitserver/ {print \$1}") \
      --puppet-classes 'git::server'

     HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/infra\/gitserver$/) {print \$1}")
     hammer hostgroup set-parameter \
       --hostgroup-id "${HgID}" \
       --name "kt_activation_keys" \
       --value "act-${LC_ENV_LOWER}-infra-gitserver-x86_64"
   done


#CONTAINERHOST
MAJOR="7"
LOCATIONS="${LOCATION1},${LOCATION2}"
 for LC_ENV in DEV QA PROD
 do
   LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
   ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/infra$/) {print \$1}")
   hammer hostgroup create --name "containerhost" \
     --parent-id ${ParentID} \
     --organizations "${ORG}" \
     --locations "${LOCATIONS}" \
     --content-view "ccv-infra-containerhost" \
     --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_ccv_infra_containerhost/ {print \$1}") \
     --puppet-classes 'docker'

    HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/infra\/containerhost$/) {print \$1}")
    hammer hostgroup set-parameter \
      --hostgroup-id "${HgID}" \
      --name "kt_activation_keys" \
      --value "act-${LC_ENV_LOWER}-infra-containerhost-x86_64"
  done

#CAPSULE
MAJOR="7"
LOCATIONS="${LOCATION1}"
  for LC_ENV in DEV QA PROD
  do
    LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/infra$/) {print \$1}")
    hammer hostgroup create --name "capsule" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "ccv-infra-capsule" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_ccv_infra_capsule/ {print \$1}")

     HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/infra\/capsule$/) {print \$1}")
     hammer hostgroup set-parameter \
       --hostgroup-id "${HgID}" \
       --name "kt_activation_keys" \
       --value "act-${LC_ENV_LOWER}-infra-capsule-x86_64"
  done

#LOGHOST
MAJOR="6"
LOCATIONS="${LOCATION1},${LOCATION2}"
  for LC_ENV in DEV QA PROD
  do
    LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/infra$/) {print \$1}")
    hammer hostgroup create --name "loghost" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "cv-os-rhel-6Server" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_cv_os_rhel_${MAJOR}Server/ {print \$1}")

     HgID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}\/infra\/loghost$/) {print \$1}")
     hammer hostgroup set-parameter \
       --hostgroup-id "${HgID}" \
       --name "kt_activation_keys" \
       --value "act-${LC_ENV_LOWER}-infra-loghost-x86_64"
  done


MAJOR="7"
LOCATIONS="${LOCATION1},${LOCATION2},${LOCATION3}"
  for LC_ENV in Web-DEV Web-QA Web-UAT Web-PROD
  do
    LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
    ParentID=$(hammer --output csv hostgroup list --per-page 999 | awk -F"," "(\$3 ~ /^${LC_ENV_LOWER}\/rhel-${MAJOR}server-${ARCH}$/) {print \$1}")
    hammer hostgroup create --name "acmeweb" \
      --parent-id ${ParentID} \
      --organizations "${ORG}" \
      --locations "${LOCATIONS}" \
      --content-view "ccv-biz-acmeweb" \
      --environment-id $(hammer --output csv environment list --per-page 999 | awk -F "," "/KT_${ORG}_${LC_ENV}_ccv_biz_acmeweb/ {print \$1}")
  done



MAJOR="7"
LOCATIONS="${LOCATION1},${LOCATION2},${LOCATION3}"
  for LC_ENV in Web-DEV Web-QA Web-UAT Web-PROD
  do
    LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
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



MAJOR="7"
LOCATIONS="${LOCATION1},${LOCATION2},${LOCATION3}"
  for LC_ENV in Web-DEV Web-QA Web-UAT Web-PROD
  do
    LC_ENV_LOWER=$(echo ${LC_ENV} | tr '[[:upper:]' '[[:lower:]]')
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

