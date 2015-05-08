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
wget -O /tmp/bareos6.key http://download.bareos.org/bareos/release/latest/RHEL_6/repodata/repomd.xml.key
hammer gpg create --name 'GPG-Bareos-RHEL6' --organization "$ORG" --key /tmp/bareos6.key

# EPEL 6 & 7 GPG keys (EPEL 6 only if enabled in config file)
wget -O /tmp/EPEL7.key https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 
hammer gpg create --name 'GPG-EPEL-RHEL7' --organization "$ORG" --key /tmp/EPEL7.key

if [ "$EPEL6_ENABLED" -eq 1 ]
then
	wget -O /tmp/EPEL6.key https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
	hammer gpg create --name 'GPG-EPEL-RHEL6' --organization "$ORG" --key /tmp/EPEL6.key
fi

# VMware (R) tools GPG key
wget -O /tmp/vmware.key wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub
hammer gpg create --name 'GPG-VMware-RHEL6' --organization "$ORG" --key /tmp/vmware.key

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
# PRODUCTS AND REPOSITORIES
#
###################################################################################################

# RHEL7 repos
hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (Kickstart)'  
hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (RPMs)'  
hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server - RH Common (RPMs)'  
hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'RHN Tools for Red Hat Enterprise Linux 7 Server (RPMs)'  

# TODO do we need additional channels for Sat 6.1 (satellite-tools?)

# RHEL6 repos only if RHEL6_ENABLED param is set to 1 in config file
if [ "$RHEL6_ENABLED" -eq 1 ]
then

	hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server (Kickstart)'  
	hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server (RPMs)'  
	hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server - RH Common (RPMs)'  
	hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'RHN Tools for Red Hat Enterprise Linux 6 Server (RPMs)'  
  
fi

# sync all RHEL7 packages
hammer product synchronize --organization $ORG --name  'Red Hat Enterprise Linux Server' --async

# set sync plan
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  'Red Hat Enterprise Linux Server' 


# TODO check if we sync already the repos for 3rd party software here (EPEL, Bareos, VMware Tools)

# Bareos Backup Management Software repository sync
hammer product create --name='Bareos-Backup-RHEL6' --organization="$ORG"
hammer product create --name='Bareos-Backup-RHEL7' --organization="$ORG"
hammer repository create --name='Bareos-RHEL7-x86_64' --organization="$ORG" --product='Bareos-Backup-RHEL7' --content-type='yum' --publish-via-http=true --url=http://download.bareos.org/bareos/release/latest/RHEL_7/

# TODO check what happens here since Bareos is using the same RHEL6 repo for both i686 and x86_64
hammer repository create --name='Bareos-RHEL6-x86_64' --organization="$ORG" --product='Bareos-Backup-RHEL6' --content-type='yum' --publish-via-http=true --url=http://download.bareos.org/bareos/release/latest/RHEL_6/

# add according GPG keys imported during step 1
hammer product update --gpg-key 'GPG-Bareos-RHEL7' --name 'Bareos-Backup-RHEL7' --organization $ORG
hammer product update --gpg-key 'GPG-Bareos-RHEL6' --name 'Bareos-Backup-RHEL6' --organization $ORG

# add both products to our daily sync plan created during step 1
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "Bareos-Backup-RHEL6"
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "Bareos-Backup-RHEL7"
# run synchronization task with async option for both products
hammer repository synchronize --organization "$ORG" --product "Bareos-Backup-RHEL6" --async
hammer repository synchronize --organization "$ORG" --product "Bareos-Backup-RHEL7" --async

# TODO additional repos 2 sync as defined in CONFIG section

###################################################################################################
#
# EPEL Repo for RHEL6 repos only if EPEL6_ENABLED param is set to 1 in config file
#
###################################################################################################
if [ "$EPEL6_ENABLED" -eq 1 ]
then
	hammer product create --name='EPEL6' --organization="$ORG"
	hammer repository create --name='EPEL6-x86_64' --organization="$ORG" --product='EPEL6' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/6/x86_64/
	hammer repository synchronize --organization "$ORG" --product "EPEL6" --async

	hammer product update --gpg-key 'GPG-EPEL-RHEL7' --name 'EPEL7' --organization $ORG

	# add it to daily sync plan
	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "EPEL6"
fi

# enable and sync OSE3 repositories
# TODO
echo "TODO" 


###################################################################################################
#
# EPEL 7 (we need to divide between EPEL 6 and 7 due to different gpg keys)
#
###################################################################################################
hammer product create --name='EPEL7' --organization="$ORG"
# it seems that Sat6 can not handle the mirroring of EPEL repo. if it does not work use a static mirror from http://mirrors.fedoraproject.org/publiclist/EPEL/7/x86_64/ instead,like
# hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7' --content-type='yum' --publish-via-http=true --url= http://ftp-stud.hs-esslingen.de/pub/epel/7/x86_64/
hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/
hammer product update --gpg-key 'GPG-EPEL-RHEL7' --name 'EPEL7' --organization $ORG

hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "EPEL7"
hammer repository synchronize --organization "$ORG" --product "EPEL7" --async


###################################################################################################
#
# EPEL 7-2 (we need to clone the entire repo to apply different filters, see ref arch for details)
#
###################################################################################################
hammer product create --name='EPEL7-2' --organization="$ORG"
# it seems that Sat6 can not handle the mirroring of EPEL repo. if it does not work use a static mirror from http://mirrors.fedoraproject.org/publiclist/EPEL/7/x86_64/ instead,like
# hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7-2' --content-type='yum' --publish-via-http=true --url= http://ftp-stud.hs-esslingen.de/pub/epel/7/x86_64/
hammer repository create --name='EPEL7-x86_64-2' --organization="$ORG" --product='EPEL7-2' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/
hammer product update --gpg-key 'GPG-EPEL-RHEL7' --name 'EPEL7-2' --organization $ORG

hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "EPEL7-2"
hammer repository synchronize --organization "$ORG" --product "EPEL7-2" --async


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
	hammer product create --name='PuppetForge' --organization=$ORG
	hammer repository create --name='Puppet Forge' --organization=$ORG --product='Forge' --content-type='puppet' --publish-via-http=true --url=https://forge.puppetlabs.com
fi

###################################################################################################
#
# ACME product and repositories
#
###################################################################################################
hammer product create --name="$ORG" --organization=$ORG
hammer repository create --name="$ORG RPM Repo" --organization=$ORG --product="$ORG" --content-type='yum' --publish-via-http=true --url="$CUSTOM_YUM_REPO"
# TODO this does not work as expected. uncomment after fixing 
hammer repository create --name="$ORG Puppet Repo" --organization=$ORG --product="$ORG" --content-type='puppet' --publish-via-http=true --url="$CUSTOM_PUPPET_REPO"
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name "$ORG"
# TODO de-comment the following line if we provide example rpm packages. otherwise the sync will fail so we might want to skip it
# hammer repository synchronize --organization "$ORG" --product "$ORG" --async
