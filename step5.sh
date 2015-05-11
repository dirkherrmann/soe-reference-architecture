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
# CV mariadb (puppet only since mariadb is part of RHEL7 and we don't use RHEL6 as DB server)
# 
###################################################################################################
hammer content-view create --name "cv-app-mariadb" --description "MariaDB Content View" --organization "$ORG"
# TODO figure out how to deal with puppetforge. If enabled we create product and repo during step2.
# but we don't want to sync the entire repo to local disk. We can not filter at the repo but only CV level.
# I've tried using the repo discovery and URLs directly to the module. None works. 
# As a temporary workaround we are downloading and pushing the modules directly until we made a decision.

# download the example42/mariadb puppet module
wget -O /tmp/mariadb.tgz https://forgeapi.puppetlabs.com/v3/files/example42-mariadb-2.0.16.tar.gz
hammer repository upload-content --organization $ORG --product $ORG --name "$ORG Puppet Repo" --path /tmp/mariadb.tgz
hammer content-view puppet-module add --content-view cv-app-mariadb --name mariadb --organization $ORG
hammer content-view  publish --name "cv-app-mariadb" --organization "$ORG" --async

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


# add puppet modules from $ORG product repo to this CV
# hammer content-view puppet-module add --content-view cv-os-rhel-7Server --name <module_name> --organization $ORG

hammer content-view  publish --name "cv-app-wordpress" --organization "$ORG" --async



###################################################################################################
#
# CV docker-host (adds extras channel + filter)
# 
###################################################################################################
hammer content-view create --name "cv-app-docker" --description "Docker Host Content View" --organization "$ORG"
# TODO add puppet repo and modules as well
hammer content-view add-repository --organization "$ORG" --repository 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64' --name "cv-app-docker" --product 'Red Hat Enterprise Linux Server'
hammer content-view filter create --type rpm --name 'docker-package-only' --description 'Only include the docker rpm package' --inclusion=true --organization "$ORG" --repositories 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64' --content-view "cv-app-docker"
hammer content-view filter rule create --name docker --organization "$ORG" --content-view "cv-app-docker" --content-view-filter 'docker-package-only'
# TODO let's try the latest version (no version filter). If we figure out that it does not work add a filter for docker rpm version here or inside the puppet module

# add puppet modules from $ORG product repo to this CV
hammer content-view puppet-module add --content-view cv-app-docker --name profile_dockerhost --organization $ORG
# publish it
hammer content-view  publish --name "cv-app-docker" --organization "$ORG" --async
# promote it to stage dev
# TODO issue here, thanks mmccune to point me there: https://bugzilla.redhat.com/show_bug.cgi?id=1219585
# we need to specify the version ID if there is more than version one
# workaround provided by mmccune:
VID=`hammer content-view version list --content-view-id "cv-app-docker" | awk -F'|' '{print $1}' | sort -n  | tac | head -n 1`
# echo "Promoting CV VersionID: $VID"

# commenting this out since we can not promote until publish has been done
# TODO write a loop which waits until the publish is done, maybe in background
# STDOUT of publish command: Content view is being promoted with task 7410dabf-334e-4368-b72d-d677af88bce8
# check if running hammer task progress --id 7410dabf-334e-4368-b72d-d677af88bce8
# hammer content-view version promote --content-view "cv-app-docker" --organization "$ORG" --async --to-lifecycle-environment DEV --id $VID
# NOTE: we can not promote it to the next stage (QA) until promotion to DEV is running
# TODO: figure out how we can schedule the 2nd promotion in background waiting on finishing the first one

###################################################################################################
###################################################################################################
#												  #
# COMPOSITE CONTENT VIEW CREATION								  #
#												  #
###################################################################################################
###################################################################################################


###################################################################################################
#
# CCV Core Build + docker-host 
# 
###################################################################################################
hammer content-view create --name "ccv-infra-dockerhost" --composite --description "CCV for DockerHost Role as part of Infra Services" --organization $ORG --repositories 'cv-os-rhel-7Server,cv-app-docker'
hammer content-view publish --name "ccv-infra-dockerhost" --organization "$ORG" --async


###################################################################################################
#
# CCV Core Build + wordpress + mariadb
# 
###################################################################################################
hammer content-view create --name "ccv-biz-acmeweb" --composite --description "CCV for ACME Website components" --organization $ORG --repositories 'cv-os-rhel-7Server,cv-app-wordpress,cv-app-mariadb'
hammer content-view publish --name "ccv-biz-acmeweb" --organization "$ORG" --async




