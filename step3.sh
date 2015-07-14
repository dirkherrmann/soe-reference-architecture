#! /bin/bash

#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 

# TODO short desc and outcome of this step

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

DIR="$PWD"
source "${DIR}/common.sh"

# TODO since in this step we rely on the RH subscription and we don't ship the manifest as part of these scripts
# we should check here if at least the minimum number of subs we need is there.
# hammer --csv subscription list --organization $ORG --per-page 999

###################################################################################################
#
# GPG KEYS
#
###################################################################################################

# Bareos GPG keys
wget -O /tmp/bareos7.key http://download.bareos.org/bareos/release/latest/RHEL_7/repodata/repomd.xml.key
hammer gpg create --name 'GPG-Bareos-RHEL7' --organization "$ORG" --key /tmp/bareos7.key

if [ "$RHEL6_ENABLED" -eq 1 ]
then
	wget -O /tmp/bareos6.key http://download.bareos.org/bareos/release/latest/RHEL_6/repodata/repomd.xml.key
	hammer gpg create --name 'GPG-Bareos-RHEL6' --organization "$ORG" --key /tmp/bareos6.key
fi

# EPEL 6 & 7 GPG keys (EPEL 6 only if enabled in config file)
wget -O /tmp/EPEL7.key https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 
hammer gpg create --name 'GPG-EPEL-RHEL7' --organization "$ORG" --key /tmp/EPEL7.key

if [ "$RHEL6_ENABLED" -eq 1 ]
then
	wget -O /tmp/EPEL6.key https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
	hammer gpg create --name 'GPG-EPEL-RHEL6' --organization "$ORG" --key /tmp/EPEL6.key
fi

# VMware (R) tools GPG key
if [ "$RHEL6_ENABLED" -eq 1 ]
then

	wget -O /tmp/vmware.key wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub
	hammer gpg create --name 'GPG-VMware-RHEL6' --organization "$ORG" --key /tmp/vmware.key
fi

# Zabbix GPG key (both RHEL6 and RHEL7)
wget -O /tmp/ZABBIX.key http://repo.zabbix.com/RPM-GPG-KEY-ZABBIX
hammer gpg create --name 'GPG-ZABBIX' --organization "$ORG" --key /tmp/ZABBIX.key 

# ACME custom GPG key
# to ensure that our example rpms will work we do not create but download and use the GPG key we've created for the reference architecture
# TODO create one and upload into github


###################################################################################################
#
# SYNC PLAN
#
###################################################################################################

# create sync plan for daily sync
hammer sync-plan create --name 'daily sync at 3 a.m.' --description 'A daily sync plans runs every morning a 3 a.m.' --enabled=true --interval daily --organization "$ORG" --sync-date '2015-04-15 03:00:00'


###################################################################################################
#
# ACME product and repositories
#
###################################################################################################
hammer product create --name="$ORG" --organization="$ORG"
hammer repository create --name="$ORG RPM Repo" --organization="$ORG" --product="$ORG" --content-type='yum' --publish-via-http=true --url="$CUSTOM_YUM_REPO"
# TODO this does not work as expected. uncomment after fixing 
hammer repository create --name="$ORG Puppet Repo" --organization="$ORG" --product="$ORG" --content-type='puppet' --publish-via-http=true --url="$CUSTOM_PUPPET_REPO"
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name "$ORG"
# TODO de-comment the following line if we provide example rpm packages. otherwise the sync will fail so we might want to skip it
# hammer repository synchronize --organization "$ORG" --product "$ORG" --async


###################################################################################################
#
# EXAMPLE PUPPET MODULES PUSH 
#
###################################################################################################
# we need to push our pre-built puppet modules into git and enable the repo sync
# TODO double-check if this is the right chapter for this task

# TODO create a local git repo and make it available as sync repo
# in the meantime let's push the modules inside our example module dir directly
# push the example puppet module into our $ORG Puppet Repo
for module in $(ls ./puppet/*/*gz)
do
	echo "Pushing example module $module into our puppet repo"
	hammer -v repository upload-content --organization "$ORG" --product ACME --name "ACME Puppet Repo" --path $module
done

# the following lines are the bash work-around for pulp-puppet-module-builder
#for file in $@
#do
#    echo $file,`sha256sum $file | awk '{ print $1 }'`,`stat -c '%s' $file`
#done

###################################################################################################
#
# RED HAT PRODUCTS AND REPOSITORIES
#
###################################################################################################

# RHEL7 repos
hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (Kickstart)'  
hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (RPMs)'  
#hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server - RH Common (RPMs)'  
hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server - Extras (RPMs)' 
# TODO adapt it to non-beta repo after GA
hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Satellite Tools 6 Beta (for RHEL 7 Server) (RPMs)'
# TODO after I've enabled and tried to sync the products have been messed up and could not be accessed anymore via UI and hammer
hammer repository-set enable --organization "$ORG" --product 'Red Hat Software Collections for RHEL Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 7 Server'

# RHEL6 repos only if RHEL6_ENABLED param is set to 1 in config file
if [ "$RHEL6_ENABLED" -eq 1 ]
then
	# RHEL 6 legacy (example 6.5)
	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6.5' --name 'Red Hat Enterprise Linux 6 Server (Kickstart)'  
	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6.5' --name 'Red Hat Enterprise Linux 6 Server (RPMs)'  
	#hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6.5' --name 'Red Hat Enterprise Linux 6 Server - RH Common (RPMs)'  
	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6.5' --name 'Red Hat Enterprise Linux 6 Server - Extras (RPMs)' 
	# TODO adapt it to non-beta repo after GA
	# TODO repo not found error here
	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Satellite Tools 6 Beta (for RHEL 6 Server) (RPMs)'
	hammer repository-set enable --organization "$ORG" --product 'Red Hat Software Collections for RHEL Server' --basearch='x86_64' --releasever='6.5' --name 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 6 Server'

	# if we are using RHEV we need the RHEV agents in the dedicated channel for RHEL6 while RHEL7 includes in RH Common
	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6.5' --name 'Red Hat Enterprise Virtualization Agents for RHEL 6 Server (RPMs)'

#	# RHEL 6 latest
#	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server (Kickstart)'  
#	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server (RPMs)'  
#	# hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server - RH Common (RPMs)'  
#	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server - Extras (RPMs)' 
#	# TODO adapt it to non-beta repo after GA
#	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Satellite Tools 6 Beta (for RHEL 6 Server) (RPMs)'
#	hammer repository-set enable --organization "$ORG" --product 'Red Hat Software Collections for RHEL Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 6 Server'
#	hammer repository-set enable --organization "$ORG" --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6.5' --name 'Red Hat Enterprise Virtualization Agents for RHEL 6 Server (RPMs)'
  
fi

# sync all RHEL packages
hammer product synchronize --organization "$ORG" --name  'Red Hat Enterprise Linux Server' --async
hammer product synchronize --organization "$ORG" --name  'Red Hat Software Collections for RHEL Server' --async

# set sync plan
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  'Red Hat Enterprise Linux Server' 
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  'Red Hat Software Collections for RHEL Server'

# JBoss Enterprise Application Platform - DISABLED TEMPORARY SINCE WE DO NOT USE IT HERE
#hammer repository-set enable --organization "$ORG" --product 'JBoss Enterprise Application Platform' --basearch='x86_64' --releasever='7Server' --name 'JBoss Enterprise Application Platform 6.4 (RHEL 7 Server) (RPMs)'
#hammer product synchronize --organization "$ORG" --name  'JBoss Enterprise Application Platform' --async
#hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  'JBoss Enterprise Application Platform'

# Satellite 6.1 Capsule

# this is the Satellite 6.1 pre-GA (Beta)repo
echo -e "\n\n\nWe enable the Satellite 6 Capsule Repo for ****BETA**** here. POST GA please change this inside step3.sh to the final repository.\n\n\n"
hammer repository-set enable --organization "$ORG" --product 'Red Hat Satellite Capsule Beta'  --basearch='x86_64' --releasever='7Server' --name 'Red Hat Satellite Capsule 6 Beta (for RHEL 7 Server) (RPMs)'
hammer product synchronize --organization "$ORG" --name  'Red Hat Satellite Capsule Beta' --async
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  'Red Hat Satellite Capsule Beta'

# TODO this repo is empty as of today, we need to use the beta repo instead. check after GA if we now have content inside
# POST GA PLEASE COMMENT OUT THE 3 LINES ABOVE AND UNCOMMENT THE 3 LINES BELOW
#hammer repository-set enable --organization "$ORG" --product 'Red Hat Satellite Capsule'  --basearch='x86_64' --releasever='7Server' --name 'Red Hat Satellite Capsule 6.1 (for RHEL 7 Server) (RPMs)'
#hammer product synchronize --organization "$ORG" --name  'Red Hat Satellite Capsule' --async
#hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  'Red Hat Satellite Capsule'

# TODO additional repos 2 sync as defined in CONFIG section

###################################################################################################
#
# Bareos Backup Management Software
#
###################################################################################################
hammer product create --name='Bareos-Backup-RHEL7' --organization="$ORG"
hammer repository create --name='Bareos-RHEL7-x86_64' --organization="$ORG" --product='Bareos-Backup-RHEL7' --content-type='yum' --publish-via-http=true --url=http://download.bareos.org/bareos/release/latest/RHEL_7/
# add according GPG keys imported during step 1
hammer product update --gpg-key 'GPG-Bareos-RHEL7' --name 'Bareos-Backup-RHEL7' --organization "$ORG"
# add to our daily sync plan created during step 1
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  "Bareos-Backup-RHEL7"
# run synchronization task with async option for both products
hammer repository synchronize --organization "$ORG" --product "Bareos-Backup-RHEL7" --async

# Bareos 6 repos only if RHEL6_ENABLED param is set to 1 in config file
if [ "$RHEL6_ENABLED" -eq 1 ]
then

	hammer product create --name='Bareos-Backup-RHEL6' --organization="$ORG"
	# TODO check what happens here since Bareos is using the same RHEL6 repo for both i686 and x86_64
	hammer repository create --name='Bareos-RHEL6-x86_64' --organization="$ORG" --product='Bareos-Backup-RHEL6' --content-type='yum' --publish-via-http=true --url=http://download.bareos.org/bareos/release/latest/RHEL_6/
	hammer product update --gpg-key 'GPG-Bareos-RHEL6' --name 'Bareos-Backup-RHEL6' --organization "$ORG"
	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  "Bareos-Backup-RHEL6"
	hammer repository synchronize --organization "$ORG" --product "Bareos-Backup-RHEL6" --async
fi


###################################################################################################
#
# VMware Tools (only required if RHEL6) only if RHEL6_ENABLED param is set to 1 in config file
#
###################################################################################################
if [ "$RHEL6_ENABLED" -eq 1 ]
then
	hammer product create --name='VMware-Tools-RHEL6' --organization="$ORG"
	# TODO add VMware vSphere version or repo to config file
	hammer repository create --name='VMware-Tools-RHEL6-x86_64' --organization="$ORG" --product='VMware-Tools-RHEL6' --content-type='yum' --publish-via-http=true --url='http://packages.vmware.com/tools/esx/5.1u2/rhel6/x86_64/'
	hammer product update --gpg-key 'GPG-VMware-RHEL6' --name 'VMware-Tools-RHEL6' --organization "$ORG"
	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  "VMware-Tools-RHEL6"
	hammer repository synchronize --organization "$ORG" --product "VMware-Tools-RHEL6" --async

fi

###################################################################################################
#
# ZABBIX Repos for RHEL7 and RHEL6 (only if RHEL6_ENABLED param is set to 1 in config file)
#
###################################################################################################

# in this case (same GPG key used we do not need to divide between RHEL 6 and 7: one product Zabbix for both
hammer product create --name='Zabbix-Monitoring' --organization="$ORG"
hammer repository create --name='Zabbix-RHEL7-x86_64' --organization="$ORG" --product='Zabbix-Monitoring' --content-type='yum' --publish-via-http=true --url=http://repo.zabbix.com/zabbix/2.4/rhel/7/x86_64/

if [ "$RHEL6_ENABLED" -eq 1 ]
then
	hammer repository create --name='Zabbix-RHEL6-x86_64' --organization="$ORG" --product='Zabbix-Monitoring' --content-type='yum' --publish-via-http=true --url=http://repo.zabbix.com/zabbix/2.4/rhel/6/x86_64/
fi

# add according GPG keys imported during step 1
hammer product update --gpg-key 'GPG-ZABBIX' --name 'Zabbix-Monitoring' --organization "$ORG"
# add to our daily sync plan created during step 1
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  "Zabbix-Monitoring"
# run synchronization task with async option for both products
hammer repository synchronize --organization "$ORG" --product "Zabbix-Monitoring" --async






###################################################################################################
#
# EPEL Repo for RHEL6 repos only if RHEL6_ENABLED param is set to 1 in config file == DEPRECATED DUE TO ZABBIX ==
#
###################################################################################################
#if [ "$RHEL6_ENABLED" -eq 1 ]
#then
#	hammer product create --name='EPEL6-CoreBuild' --organization="$ORG"
#	hammer repository create --name='EPEL6-CoreBuild-x86_64' --organization="$ORG" --product='EPEL6-CoreBuild' --content-type='yum' --publish-via-http=true --url=http://ftp.tu-chemnitz.de/pub/linux/fedora-epel/6/x86_64/
#	hammer repository synchronize --organization "$ORG" --product "EPEL6" --async

#	hammer product update --gpg-key 'GPG-EPEL-RHEL6' --name 'EPEL6' --organization "$ORG"

#	# add it to daily sync plan
#	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  "EPEL6"
#fi


###################################################################################################
#
# EPEL 7 CoreBuild (we're syncing EPEL7 twice to apply different filters) == DEPRECATED DUE TO ZABBIX ==
#
###################################################################################################
#hammer product create --name='EPEL7-CoreBuild' --organization="$ORG"
## it seems that Sat6 can not handle the mirroring of EPEL repo. if it does not work use a static mirror from http://mirrors.fedoraproject.org/publiclist/EPEL/7/x86_64/ instead,like
## hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7' --content-type='yum' --publish-via-http=true --url= http://ftp-stud.hs-esslingen.de/pub/epel/7/x86_64/
#hammer repository create --name='EPEL7-CoreBuild-x86_64' --organization="$ORG" --product='EPEL7-CoreBuild' --content-type='yum' --publish-via-http=true --url=http://ftp.tu-chemnitz.de/pub/linux/fedora-epel/7/x86_64/
#hammer product update --gpg-key 'GPG-EPEL-RHEL7' --name 'EPEL7-CoreBuild' --organization "$ORG"

#hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  "EPEL7"
#hammer repository synchronize --organization "$ORG" --product "EPEL7-CoreBuild" --async


###################################################################################################
#
# EPEL 7-APP (we need to clone the entire repo to apply different filters, see ref arch for details)
#
###################################################################################################
hammer product create --name='EPEL7-APP' --organization="$ORG"
# it seems that Sat6 can not handle the mirroring of EPEL repo. if it does not work use a static mirror from http://mirrors.fedoraproject.org/publiclist/EPEL/7/x86_64/ instead,like
# hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7-APP' --content-type='yum' --publish-via-http=true --url= http://ftp-stud.hs-esslingen.de/pub/epel/7/x86_64/
hammer repository create --name='EPEL7-APP-x86_64' --organization="$ORG" --product='EPEL7-APP' --content-type='yum' --publish-via-http=true --url=http://ftp.tu-chemnitz.de/pub/linux/fedora-epel/7/x86_64/
hammer product update --gpg-key 'GPG-EPEL-RHEL7' --name 'EPEL7-APP' --organization "$ORG"

hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization "$ORG" --name  "EPEL7-APP"
hammer repository synchronize --organization "$ORG" --product "EPEL7-APP" --async


###################################################################################################
#
# Puppetforge repo
#
###################################################################################################
if [ "$PUPPETFORGE_ENABLED" -eq 1 ]
then
	echo "Please note that currently you can not sync a particular subset, only the entire repo."
	echo "For further information have a look here: https://access.redhat.com/solutions/1377233"
	# we recommend to let this option disabled until you really want to sync the entire forge repo
	hammer product create --name='PuppetForge' --organization="$ORG"
	hammer repository create --name='Puppet Forge' --organization="$ORG" --product='Forge' --content-type='puppet' --publish-via-http=true --url=https://forge.puppetlabs.com
fi

