#! /bin/bash

#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 

# TODO short desc and outcome of this step

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

DIR="$PWD"
source "${DIR}/common.sh"


###################################################################################################
#
# CORE BUILD PUPPET MODULE PUSH 
#
###################################################################################################
# we need to push our pre-built puppet modules into git and enable the repo sync
# TODO double-check if this is the right chapter for this task

# the following lines are the bash work-around for pulp-puppet-module-builder
#for file in $@
#do
#    echo $file,`sha256sum $file | awk '{ print $1 }'`,`stat -c '%s' $file`
#done

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

# we are creating an initial version just containing RHEL 7.0 bits based on a date filter between RHEL 7.0 GA and before RHEL 7.1 GA
hammer content-view filter create --type erratum --name 'rhel-7.0-only' --description 'Only include RHEL 7.0 bits' --inclusion=true --organization "$ORG" --repositories 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64' --content-view "cv-app-docker"
hammer content-view filter rule create  --organization "$ORG" --content-view "cv-app-docker" --content-view-filter 'rhel-7.0-only' --start-date 2014-06-09 --end-date 2015-03-01 --types enhancement,bugfix,security


# TODO add all puppet modules which are part of core build based on our naming convention
hammer content-view puppet-module add --content-view cv-os-rhel-7Server --name motd --organization $ORG
# TODO description only available in logfile: /var/log/foreman/production.log
# 2015-05-04 20:06:23 [I]   Parameters: {"id"=>"8", "description"=>"added motd puppet module", "organization_id"=>"4", "api_version"=>"v2", "content_view"=>{"id"=>"8", "description"=>"added motd puppet module"}}

hammer content-view  publish --name "cv-os-rhel-7Server" --organization "$ORG" --async

