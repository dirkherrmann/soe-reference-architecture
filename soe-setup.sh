#! /bin/bash

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




# assign GPG keys to according products
# Note: we've synced the products already during running soe-prep-setup.sh and created GPG keys earlier. 
# Here we are adding the keys to the products
hammer product update --gpg-key 'GPG-Bareos-RHEL7' --name 'Bareos-Backup-RHEL7' --organization $ORG
hammer product update --gpg-key 'GPG-Bareos-RHEL6' --name 'Bareos-Backup-RHEL6' --organization $ORG



###################################################################################################
#
# CV wordpress (contains EPEL7 + Filter)
# 
###################################################################################################
hammer content-view create --name "cv-app-wordpress" --description "Wordpress Content View" --organization "$ORG"
# TODO add puppet repo and modules as well
hammer content-view add-repository --organization "$ORG" --repository 'EPEL7-x86_64' --name "cv-app-wordpress" --product 'EPEL7'
hammer content-view filter create --type rpm --name 'wordpress-packages-only' --description 'Only include the wordpress rpm package' --inclusion=true --organization "$ORG" --repositories 'EPEL7-x86_64' --content-view "cv-app-wordpress"
hammer content-view filter rule create --name wordpress --organization "$ORG" --content-view "cv-app-wordpress" --content-view-filter 'wordpress-packages-only'
hammer content-view  publish --name "cv-app-wordpress" --organization "$ORG" --async


