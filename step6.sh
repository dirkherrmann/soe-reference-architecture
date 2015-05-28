#! /bin/bash

#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 


# TODO short desc and outcome of this step

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

DIR="$PWD"
source "${DIR}/common.sh"

# since we need our core build CV IDs more than once let's use variables for them
# note: we don't need to CV IDs but the VERSION IDs of most current versions for our CCV creation
if [ "$RHEL6_ENABLED" -eq 1 ]
then
	export RHEL6_CB_VID=`get_latest_version cv-os-rhel-6Server`
	echo "Identified VERSION ID ${RHEL6_CB_VID} as most current version of our RHEL6 Core Build"
fi

# check if this variable is empty and exit if
if [ -z ${RHEL7_CB_VID} ]
then 
	echo "Could not identify latest CV version id of RHEL 7 Core Build. Exit."; exit; 
else 
	export RHEL7_CB_VID=`get_latest_version cv-os-rhel-7Server`
	echo "Identified VERSION ID ${RHEL7_CB_VID} as most current version of our RHEL7 Core Build"
fi

###################################################################################################
#
# CV mariadb (puppet only since mariadb is part of RHEL7 and we don't use RHEL6 here) and according CCV
# 
###################################################################################################
hammer content-view create --name "cv-app-mariadb" --description "MariaDB Content View" --organization "$ORG"

# since MariaDB is included in RHEL7 (and therefore in RHEL7 Core Build) we only need to add RHSCL if we use RHEL6
if [ "$RHEL6_ENABLED" -eq 1 ]
then
	hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 6 Server x86_64 7Server' --name "cv-app-mariadb" --product 'Red Hat Software Collections for RHEL Server'
	hammer content-view filter create --type rpm --name 'mariadb-packages-only' --description 'Only include the MariaDB rpm packages' --inclusion=true --organization "$ORG" --repositories 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 6 Server x86_64 7Server' --content-view "cv-app-mariadb"
	hammer content-view filter rule create --name mariadb --organization "$ORG" --content-view "cv-app-mariadb" --content-view-filter 'mariadb-packages-only'

fi

hammer content-view puppet-module add --content-view cv-app-mariadb --name mariadb --organization $ORG
hammer content-view  publish --name "cv-app-mariadb" --organization "$ORG" # --async # no async anymore, we need to wait until its published to created the CCV

# Note: we do not create a CCV for MariaDB as we might need for a dedicated DB server yet 
# We are using this CV just as a profile inside role ccv-biz-acmeweb and ccv-biz-intranet 


###################################################################################################
#
# CV wordpress (contains EPEL7 + Filter)
# 
###################################################################################################
hammer content-view create --name "cv-app-wordpress" --description "Wordpress Content View" --organization "$ORG"
# TODO add puppet repo and modules as well
hammer content-view add-repository --organization "$ORG" --repository 'EPEL7-APP-x86_64' --name "cv-app-wordpress" --product 'EPEL7-APP'
hammer content-view filter create --type rpm --name 'wordpress-packages-only' --description 'Only include the wordpress rpm package' --inclusion=true --organization "$ORG" --repositories 'EPEL7-APP-x86_64' --content-view "cv-app-wordpress"
hammer content-view filter rule create --name wordpress --organization "$ORG" --content-view "cv-app-wordpress" --content-view-filter 'wordpress-packages-only'


# add puppet modules from $ORG product repo to this CV
hammer content-view puppet-module add --content-view cv-os-rhel-7Server --name wordpress --organization $ORG # profile specific / generic module
hammer content-view puppet-module add --content-view cv-os-rhel-7Server --name acmeweb --organization $ORG # role specific module for acmeweb

hammer content-view  publish --name "cv-app-wordpress" --organization "$ORG" # --async # no async anymore, we need to wait until its published to created the CCV


###################################################################################################
#
# CV git (contains RHSCL repo + Filter) and according CCV (user for git server AND clients)
# 
###################################################################################################
hammer content-view create --name "cv-app-git" --description "The application specific content view for git." --organization "$ORG"
# add the RHSCL repo plus filter for git packages only
hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 7 Server x86_64 7Server' --name "cv-app-git" --product 'Red Hat Software Collections for RHEL Server'

hammer content-view filter create --type rpm --name 'git-packages-only' --description 'Only include the git rpm packages' --inclusion=true --organization "$ORG" --repositories 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 7 Server x86_64 7Server' --content-view "cv-app-git"
hammer content-view filter rule create --name 'git19-*' --organization "$ORG" --content-view "cv-app-git" --content-view-filter 'git-packages-only'

# add puppet modules from $ORG product repo to this CV
hammer content-view puppet-module add --content-view "cv-app-git" --name git --organization $ORG

hammer content-view  publish --name "cv-app-git" --organization "$ORG" # --async # no async anymore, we need to wait until its published to created the CCV


###################################################################################################
#
# CV Satellite 6 Capsule
# 
###################################################################################################
hammer content-view create --name "cv-app-capsule" --description "Satellite 6 Capsule Content View" --organization "$ORG"
# TODO check if this work, repo seems to be still empty
hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Satellite Capsule 6.1 for RHEL 7 Server RPMs x86_64 7Server' --name "cv-app-capsule" --product 'Red Hat Satellite Capsule'

# Note: we do not use a puppet module here
hammer content-view  publish --name "cv-app-capsule" --organization "$ORG"  # --async # no async anymore, we need to wait until its published to created the CCV


###################################################################################################
#
# CV JBoss Enterprise Application Server 7 TODO CURRENTLY NOT USED
# 
###################################################################################################
#hammer content-view create --name "cv-app-jbosseap7" --description "JBoss EAP 7 Content View" --organization "$ORG"
## TODO which repo do we need here? TODO add this repo to step2 as well
## hammer content-view add-repository --organization "$ORG" --repository 'TODO' --name "cv-app-sat6capsule" --product 'TODO'

## TODO add puppet modules from $ORG product repo to this CV
## hammer content-view puppet-module add --content-view cv-os-rhel-7Server --name <module_name> --organization $ORG

#hammer content-view  publish --name "cv-app-jbosseap7" --organization "$ORG" --async


###################################################################################################
#
# CV docker host (adds extras channel + filter)
# 
###################################################################################################
hammer content-view create --name "cv-app-docker" --description "Docker Host Content View" --organization "$ORG"
# TODO add puppet repo and modules as well
hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64 7Server' --name "cv-app-docker" --product 'Red Hat Enterprise Linux Server'
hammer content-view filter create --type rpm --name 'docker-package-only' --description 'Only include the docker rpm package' --inclusion=true --organization "$ORG" --repositories 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64 7Server' --content-view "cv-app-docker"
hammer content-view filter rule create --name docker --organization "$ORG" --content-view "cv-app-docker" --content-view-filter 'docker-package-only'
# TODO let's try the latest version (no version filter). If we figure out that it does not work add a filter for docker rpm version here or inside the puppet module

# add puppet modules from $ORG product repo to this CV
hammer content-view puppet-module add --content-view "cv-app-docker" --name docker --organization $ORG

# publish it and grep the task id since we need to wait until the task is finished before promoting it
hammer content-view  publish --name "cv-app-docker" --organization "$ORG" # --async # no async anymore, we need to wait until its published to created the CCV


###################################################################################################
#
# CV (rsys)log host (no software since part of RHEL but just puppet)
# 
###################################################################################################
hammer content-view create --name "cv-app-rsyslog" --description "Docker Host Content View" --organization "$ORG"
# Note: we do not add software repositories in this CV since rsyslog is part of both RHEL6 and RHEL7a filter for docker rpm version here or inside the puppet module

# add puppet modules from $ORG product repo to this CV
hammer content-view puppet-module add --content-view cv-app-rsyslog --name loghost --organization $ORG

# publish it and grep the task id since we need to wait until the task is finished before promoting it
hammer content-view  publish --name "cv-app-rsyslog" --organization "$ORG" # --async # no async anymore, we need to wait until its published to created the CCV


###################################################################################################
###################################################################################################
#												  #
# COMPOSITE CONTENT VIEW CREATION (ROLES)							  #
#												  #
###################################################################################################
###################################################################################################
echo "Starting to promote our composite content views. This might take a while. Please be patient."


###################################################################################################
#
# CCV BIZ ACMEWEB (RHEL7 Core Build + MariaDB + Wordpress)
# 
###################################################################################################
APP1_CVID=`get_latest_version cv-app-mariadb`
APP2_CVID=`get_latest_version cv-app-wordpress`
hammer content-view create --name "ccv-biz-acmeweb" --composite --description "CCV for ACME including Wordpress and MariaDB" --organization $ORG --component-ids ${RHEL7_CB_VID},${APP1_CVID},${APP2_CVID}
hammer content-view publish --name "ccv-biz-acmeweb" --organization "$ORG" # --async # no async anymore, we need to wait until its published to promote it 

###################################################################################################
#
# CCV INFRA CAPSULE (RHEL7 Core Build + SAT6 CAPSULE)
# 
###################################################################################################
APP_CVID=`get_latest_version cv-app-capsule`
hammer content-view create --name "ccv-infra-capsule" --composite --description "CCV for Satellite 6 Capsule" --organization $ORG --component-ids ${RHEL7_CB_VID},${APP_CVID}
hammer content-view publish --name "ccv-infra-capsule" --organization "$ORG" # --async # no async anymore, we need to wait until its published to promote it 

###################################################################################################
#
# CCV INFRA CONTAINERHOST (RHEL7 Core Build + DOCKER CV)
# 
###################################################################################################

APP_CVID=`get_latest_version cv-app-docker`
hammer content-view create --name "ccv-infra-containerhost" --composite --description "CCV for Infra Container Host" --organization $ORG --component-ids ${RHEL7_CB_VID},${APP_CVID}
hammer content-view publish --name "ccv-infra-containerhost" --organization "$ORG" # --async # no async anymore, we need to wait until its published to promote it  


###################################################################################################
#
# CCV INFRA GIT SERVER (RHEL7 Core Build + GIT CV)
# 
###################################################################################################

# create the CCV using the RHEL7 core build
APP_CVID=`get_latest_version cv-app-git`
hammer content-view create --name "ccv-infra-gitserver" --composite --description "CCV for Infra git server" --organization $ORG --component-ids ${RHEL7_CB_VID},${APP_CVID}
hammer content-view publish --name "ccv-infra-gitserver" --organization "$ORG" # --async # no async anymore, we need to wait until its published to promote it 



###################################################################################################
#
# CCV INFRA LOGHOST (RHEL7 Core Build + RSYSLOG CV)
# 
###################################################################################################

# create the CCV using the RHEL7 core build
APP_CVID=`get_latest_version cv-app-rsyslog`
hammer content-view create --name "ccv-infra-loghost" --composite --description "CCV for central log host" --organization $ORG --component-ids ${RHEL7_CB_VID},${APP_CVID}
hammer content-view publish --name "ccv-infra-loghost" --organization "$ORG" # --async # no async anymore, we need to wait until its published to promote it 



###################################################################################################
###################################################################################################
#												  #
# COMPOSITE CONTENT VIEW PROMOTION TO FURTHER LIFECYCLE ENVIRONMENTS				  #
#												  #
###################################################################################################
###################################################################################################

# get a list of all CCVs using hammer instead of hardcoded list
# TODO test and enable the section below
#for CVID in $(hammer content-view list --organization ACME | awk -F "|" '($4 ~/true/) {print $1}');
#do
#	# define the right lifecycle path based on our naming convention
#	if echo $a |grep -qe '^ccv-biz-acmeweb.*'; then 
#		echo "biz app"; 

#	elif echo $a | grep -qe '^ccv-infra-.*'; then 
#		echo "infra app";
#	else 
#		echo "unknown type";
#	fi

#	# get most current CV version id (thanks to mmccune)
#	VID=`hammer content-view version list --content-view-id $CVID | awk -F'|' '{print $1}' | sort -n  | tac | head -n 1`
#	# promote it to dev and return task id
#	TASKID=$(hammer content-view version promote --content-view-id $CVID  --organization "$ORG" --async --to-lifecycle-environment DEV --id $VID)
#	hammer task progress --id $TASKID

#done


