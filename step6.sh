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
# CORE BUILD CV VERSION IDS
# 
###################################################################################################
# check if this variable is empty and exit if
export RHEL7_CB_VID=`get_latest_version cv-os-rhel-7Server`
if [ -z ${RHEL7_CB_VID} ]
then 
	echo "Could not identify latest CV version id of RHEL 7 Core Build. Exit."; exit; 
else 

	echo "Identified VERSION ID ${RHEL7_CB_VID} as most current version of our RHEL7 Core Build"
fi

# since we need our core build CV IDs more than once let's use variables for them
# note: we don't need to CV IDs but the VERSION IDs of most current versions for our CCV creation
if [ "$RHEL6_ENABLED" -eq 1 ]
then
	export RHEL6_CB_VID=`get_latest_version cv-os-rhel-6Server`
	echo "Identified VERSION ID ${RHEL6_CB_VID} as most current version of our RHEL6 Core Build"
fi


###################################################################################################
#
# CV git (contains RHSCL repo + Filter) and according CCV (user for git server AND clients)
# 
###################################################################################################
hammer content-view create --name "cv-app-git" \
   --description "The application specific content view for git." \
   --organization "$ORG"

# add the RHSCL repo plus filter for git packages only
hammer content-view add-repository --organization "$ORG" \
   --name "cv-app-git" \
   --repository 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 7 Server x86_64 7Server' \
   --product 'Red Hat Software Collections for RHEL Server'

RHSCLREPOID=`get_repository_id 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 7 Server x86_64 7Server'`
hammer content-view filter create --type rpm --name 'git-packages-only' \
   --description 'Only include the git rpm packages' \
   --repository-ids ${RHSCLREPOID} \
   --inclusion true \
   --content-view "cv-app-git" --organization "$ORG" 

hammer content-view filter rule create --name 'git19-*' \
   --content-view "cv-app-git" \
   --content-view-filter 'git-packages-only' \
   --organization "$ORG" 

# add puppet modules from $ORG product repo to this CV
hammer content-view puppet-module add --name git \
   --content-view "cv-app-git" --organization $ORG

# no async anymore, we need to wait until its published to created the CCV
hammer content-view  publish --name "cv-app-git" --organization "$ORG" 


###################################################################################################
#
# CCV INFRA GIT SERVER (RHEL7 Core Build + GIT CV)
# 
###################################################################################################

# create the CCV using the RHEL7 core build
APP_CVID=`get_latest_version cv-app-git`
hammer content-view create --name "ccv-infra-gitserver" \
   --composite --description "CCV for Infra git server" \
   --organization $ORG --component-ids ${RHEL7_CB_VID},${APP_CVID}

hammer content-view publish --name "ccv-infra-gitserver" --organization "$ORG" 

VID=`get_latest_version ccv-infra-gitserver`
for ENV in DEV QA PROD
do
  hammer content-view version promote --organization "$ORG" \
     --content-view "ccv-infra-gitserver" \
     --to-lifecycle-environment ${ENV} \
     --id $VID
done

###################################################################################################
#
# CV docker host (adds extras channel + filter)
# 
###################################################################################################
hammer content-view create --name "cv-app-docker" \
   --description "Docker Host Content View" \
   --organization "$ORG"

hammer content-view add-repository --organization "$ORG" \
   --repository 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64 7Server' \
   --name "cv-app-docker" --product 'Red Hat Enterprise Linux Server'

RHEXTRASREPOID=`get_repository_id 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64 7Server'`
hammer content-view filter create --type rpm --name 'docker-package-only' \
   --description 'Only include the docker rpm package' --inclusion=true \
   --organization "$ORG" --content-view "cv-app-docker" \
   --repository-ids ${RHEXTRASREPOID} 

hammer content-view filter rule create --name 'docker*' \
   --organization "$ORG" --content-view "cv-app-docker" \
   --content-view-filter 'docker-package-only'

# TODO let's try the latest version (no version filter). If we 
# figure out that it does not work add a filter for docker rpm 
# version here or inside the puppet module

# add puppet modules from $ORG product repo to this CV
hammer content-view puppet-module add --name docker \
   --content-view "cv-app-docker" \
   --organization $ORG

# publish it without using async since we need to wait 
# until the task is finished before promoting it
hammer content-view  publish --name "cv-app-docker" \
   --organization "$ORG" 

###################################################################################################
#
# CCV INFRA CONTAINERHOST (RHEL7 Core Build + DOCKER CV)
# 
###################################################################################################

APP_CVID=`get_latest_version cv-app-docker`
hammer content-view create --name "ccv-infra-containerhost" \
   --composite --description "CCV for Infra Container Host" \
   --organization $ORG --component-ids ${RHEL7_CB_VID},${APP_CVID}

hammer content-view publish --name "ccv-infra-containerhost" \
   --organization "$ORG" 

VID=`get_latest_version ccv-infra-containerhost`
for ENV in DEV QA PROD
do
  hammer content-view version promote --organization "$ORG" \
     --content-view "ccv-infra-containerhost" \
     --to-lifecycle-environment ${ENV} \
     --id $VID
done

###################################################################################################
#
# CV Satellite 6 Capsule
# 
###################################################################################################
hammer content-view create --name "cv-app-capsule" \
   --description "Satellite 6 Capsule Content View" \
   --organization "$ORG"

hammer content-view add-repository --organization "$ORG" \
   --repository 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 7 Server x86_64 7Server' \
   --name "cv-app-capsule" --product 'Red Hat Software Collections for RHEL Server'

echo -e "\n\n\nWe enable the Satellite 6 Capsule Repo for ****BETA**** here. "
echo -e "POST GA please change this inside step6.sh to the final repository.\n\n\n"

hammer content-view add-repository --organization "$ORG" \
   --repository 'Red Hat Satellite Capsule 6 Beta for RHEL 7 Server RPMs x86_64 7Server' \
   --name "cv-app-capsule" --product 'Red Hat Satellite Capsule Beta'

# POST GA PLEASE COMMENT OUT THE 1 LINE ABOVE AND UNCOMMENT THE 1 LINE BELOW
#hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Satellite Capsule 6.1 for RHEL 7 Server RPMs x86_64 7Server' --name "cv-app-capsule" --product 'Red Hat Satellite Capsule'

# Note: we do not use a puppet module here
hammer content-view  publish --name "cv-app-capsule" --organization "$ORG"  

###################################################################################################
#
# CCV INFRA CAPSULE (RHEL7 Core Build + SAT6 CAPSULE)
# 
###################################################################################################
APP_CVID=`get_latest_version cv-app-capsule`
hammer content-view create --name "ccv-infra-capsule" \
   --composite --description "CCV for Satellite 6 Capsule" \
   --organization $ORG --component-ids ${RHEL7_CB_VID},${APP_CVID}

hammer content-view publish --name "ccv-infra-capsule" \
   --organization "$ORG" 

VID=`get_latest_version ccv-infra-capsule`
for ENV in DEV QA PROD
do
  hammer content-view version promote --organization "$ORG" \
     --content-view "ccv-infra-capsule" \
     --to-lifecycle-environment ${ENV} \
     --id $VID 
done


###################################################################################################
#
# CV mariadb (puppet only since mariadb is part of RHEL7 and we don't use RHEL6 here) and according CCV
# 
###################################################################################################
hammer content-view create --name "cv-app-mariadb" \
   --description "MariaDB Content View" \
   --organization "$ORG"

# since MariaDB is included in RHEL7 (and therefore in RHEL7 Core Build) we only need to add RHSCL if we use RHEL6
if [ "$RHEL6_ENABLED" -eq 1 ]
then
	hammer content-view add-repository --name "cv-app-mariadb" \
	   --repository 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 6 Server x86_64 6Server' \
	   --product 'Red Hat Software Collections for RHEL Server' \
	   --organization "$ORG"

# TODO add required deps and then enable again and documented inside step6
#	hammer content-view filter create --type rpm --name 'mariadb-packages-only' \
#	   --description 'Only include the MariaDB rpm packages' --inclusion=true \
#	   --repositories 'Red Hat Software Collections RPMs for Red Hat Enterprise Linux 6 Server x86_64 7Server' \
#	   --content-view "cv-app-mariadb" --organization "$ORG" 

#	hammer content-view filter rule create --name mariadb --organization "$ORG" \
#	   --content-view "cv-app-mariadb" --content-view-filter 'mariadb-packages-only'

fi

# download puppetlabs mysql module and push it to ACME Puppet Repo
wget -O /tmp/puppetlabs-mysql-3.4.0.tar.gz https://forgeapi.puppetlabs.com/v3/files/puppetlabs-mysql-3.4.0.tar.gz

# add these modules to ACME puppet repo
hammer repository upload-content --organization ${ORG} \
   --product ACME --name "ACME Puppet Repo" \
   --path /tmp/puppetlabs-mysql-3.4.0.tar.gz

hammer content-view puppet-module add --content-view cv-app-mariadb \
   --name mysql --organization ${ORG}

hammer content-view  publish --name "cv-app-mariadb" --organization "$ORG" 

# Note: we do not create a CCV for MariaDB as we might need for a dedicated DB server yet 
# We are using this CV just as a profile inside role ccv-biz-acmeweb and ccv-biz-intranet 



###################################################################################################
#
# CV wordpress (contains EPEL7 + Filter)
# 
###################################################################################################
hammer content-view create --name "cv-app-wordpress" \
   --description "Wordpress Content View" \
   --organization "$ORG"

# add repository and filter
hammer content-view add-repository --name "cv-app-wordpress" \
   --repository 'EPEL7-APP-x86_64' --product 'EPEL7-APP' \
   --organization "$ORG"

EPELREPOID=`get_repository_id 'EPEL7-APP-x86_64'`
hammer content-view filter create --type rpm \
   --name 'wordpress-packages-only' \
   --description 'Only include the wordpress rpm package' \
   --inclusion=true --organization "$ORG" \
   --repository-ids ${EPELREPOID} \
   --content-view "cv-app-wordpress"

hammer content-view filter rule create --name wordpress \
   --content-view "cv-app-wordpress" \
   --content-view-filter 'wordpress-packages-only' \
   --organization "$ORG"

# download puppetlabs mysql module and push it to ACME Puppet Repo
wget -O /tmp/puppetlabs-apache-1.4.1.tar.gz https://forgeapi.puppetlabs.com/v3/files/puppetlabs-apache-1.4.1.tar.gz

# add these modules to ACME puppet repo
hammer repository upload-content --organization ${ORG} \
   --product ACME --name "ACME Puppet Repo" \
   --path /tmp/puppetlabs-apache-1.4.1.tar.gz

# add puppet modules from $ORG product repo to this CV
# role specific module for acmeweb (includes wordpress profile)
hammer content-view puppet-module add --name acmeweb \
   --content-view "cv-app-wordpress" \
   --organization $ORG 

hammer content-view  publish --name "cv-app-wordpress" --organization "$ORG" 

###################################################################################################
#
# CCV BIZ ACMEWEB (RHEL7 Core Build + MariaDB + Wordpress)
# 
###################################################################################################
APP1_CVID=`get_latest_version cv-app-mariadb`
APP2_CVID=`get_latest_version cv-app-wordpress`
hammer content-view create --name "ccv-biz-acmeweb" --composite \
   --description "CCV for ACME including Wordpress and MariaDB" \
   --component-ids ${RHEL7_CB_VID},${APP1_CVID},${APP2_CVID} \
   --organization $ORG 

hammer content-view publish --name "ccv-biz-acmeweb" --organization "$ORG" 

VID=`get_latest_version ccv-biz-acmeweb`
for ENV in Web-DEV Web-QA Web-UAT Web-PROD
do
  hammer content-view version promote --organization "$ORG" \
     --content-view "ccv-biz-acmeweb" \
     --to-lifecycle-environment ${ENV} \
     --id $VID
done


###################################################################################################
#
# CV JBoss Enterprise Application Server 7 TODO CURRENTLY NOT USED
# 
###################################################################################################
#hammer content-view create --name "cv-app-jbosseap7" --description "JBoss EAP 7 Content View" --organization "$ORG"
## TODO which repo do we need here? TODO add this repo to step2 as well
## hammer content-view add-repository --organization "$ORG" --repository 'JBoss Enterprise Application Platform 6.4 RHEL 7 Server RPMs x86_64 7Server' --name "cv-app-jbosseap7" --product 'JBoss Enterprise Application Platform'

## TODO add puppet modules from $ORG product repo to this CV
## hammer content-view puppet-module add --content-view cv-app-jbosseap7 --name jboss_admin --organization $ORG

#hammer content-view  publish --name "cv-app-jbosseap7" --organization "$ORG" --async



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


