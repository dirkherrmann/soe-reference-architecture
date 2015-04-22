#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture


# check if exists and if yes source the config file 
if -f ~/.soe-config;
then
	source ~/.soe-config
else
	echo "Could not find configuration file. Please copy the example file into your home directory and adapt it accordingly!"
	echo "# cp <path to your github copy>/soe-reference-architecture/soe-config.example ~/.soe-config"
	exit 1
fi

# function calls

import_gpg_keys()
create_lifecycle_envs()
create_content_views()

# FUNCTIONS


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


# assign GPG keys to according products
# Note: we've synced the products already during running soe-prep-setup.sh and created GPG keys earlier. 
# Here we are adding the keys to the products
hammer product update --gpg-key 'GPG-Bareos-RHEL7' --name 'Bareos-Backup-RHEL7' --organization $ORG
hammer product update --gpg-key 'GPG-Bareos-RHEL6' --name 'Bareos-Backup-RHEL6' --organization $ORG



# create the generic lifecycle env path
hammer lifecycle-environment create --organization "$ORG" --name "DEV" --description "development" --prior "Library"
hammer lifecycle-environment create --organization "$ORG" --name "QA" --description "Quality Assurance" --prior "DEV"
hammer lifecycle-environment create --organization "$ORG" --name "PROD" --description "Production" --prior "QA"

# created dedicated lifecycle env paths for our example applications
# TODO



# RHEL 6 Core Build Content View
hammer content-view create --name "cv-os-rhel-6Server" --description "RHEL Server 6 Core Build Content View" --organization "$ORG"
hammer content-view  publish --name "cv-os-rhel-6Server" --organization "$ORG" --async
# TODO figure out repo IDs
hammer content-view update --organization "$ORG" --name "cv-os-rhel-6Server" --repository-ids 456,450,451,457

# RHEL7 Core Build Content View
hammer content-view create --name "cv-os-rhel-7Server" --description "RHEL Server 7 Core Build Content View" --organization "$ORG"
hammer content-view  publish --name "cv-os-rhel-7Server" --organization "$ORG" --async
# TODO figure out repo IDs
hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-7Server" --repository-ids 452,453,454,455

# CV wordpress (contains EPEL7 + Filter)
hammer content-view create --name "cv-app-wordpress" --description "Wordpress Content View" --organization "$ORG"
# TODO add puppet repo and modules as well
hammer content-view add-repository --organization "$ORG" --repository 'EPEL7-x86_64' --name "cv-app-wordpress" --product 'EPEL7'
hammer content-view filter create --type rpm --name 'wordpress-packages-only' --description 'Only include the wordpress rpm package' --inclusion=true --organization "$ORG" --repositories 'EPEL7-x86_64' --content-view "cv-app-wordpress"
hammer content-view filter rule create --name wordpress --organization "$ORG" --content-view "cv-app-wordpress" --content-view-filter 'wordpress-packages-only'
hammer content-view  publish --name "cv-app-wordpress" --organization "$ORG" --async


