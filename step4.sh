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

###################################################################################################
#
# RHEL 6 Core Build Content View - TODO NOT TESTED YET!
#
###################################################################################################
if [ "$EPEL6_ENABLED" -eq 1 ]
then
	hammer content-view create --name "cv-os-rhel-6Server" --description "RHEL Server 6 Core Build Content View" --organization "$ORG"
	# software repositories
	hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-6Server" --repository 'Red Hat Enterprise Linux 6 Server Kickstart x86_64 6Server' --product 'Red Hat Enterprise Linux Server'
	hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-6Server" --repository 'Red Hat Enterprise Linux 6 Server RPMs x86_64 6Server' --product 'Red Hat Enterprise Linux Server'
	# TODO has to be substituted by 6.1 sat-tools channel which is not there yet
	hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-6Server" --repository 'Red Hat Enterprise Linux 6 Server - RH Common RPMs x86_64 6Server' --product 'Red Hat Enterprise Linux Server'

	# EPEL 6 only if enabled in config file
	if [ "$EPEL6_ENABLED" -eq 1 ]
	then
		hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-6Server" --repository 'EPEL6-x86_64-2' --product 'EPEL6-2'
	fi

	hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-6Server" --repository 'Bareos-RHEL6-x86_64' --product 'Bareos-Backup-RHEL6'

	# TODO puppet modules which are part of core build 

	hammer content-view  publish --name "cv-os-rhel-6Server" --organization "$ORG" --async	
fi
###################################################################################################
#
# RHEL7 Core Build Content View
#
###################################################################################################
hammer content-view create --name "cv-os-rhel-7Server" --description "RHEL Server 7 Core Build Content View" --organization "$ORG"
# software repositories
hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-7Server" --repository 'Red Hat Enterprise Linux 7 Server Kickstart x86_64 7Server' --product 'Red Hat Enterprise Linux Server'
hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-7Server" --repository 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server' --product 'Red Hat Enterprise Linux Server'
# TODO has to be substituted by 6.1 sat-tools channel which is not there yet
hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-7Server" --repository 'Red Hat Enterprise Linux 7 Server - RH Common RPMs x86_64 7Server' --product 'Red Hat Enterprise Linux Server'
hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-7Server" --repository 'EPEL7-x86_64-2' --product 'EPEL7-2'
hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-7Server" --repository 'Bareos-RHEL7-x86_64' --product 'Bareos-Backup-RHEL7'
# TODO puppet modules which are part of core build

hammer content-view  publish --name "cv-os-rhel-7Server" --organization "$ORG" --async

