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
hammer content-view puppet-module add --content-view cv-app-docker --name dockerhost --organization $ORG
# publish it
hammer content-view  publish --name "cv-app-docker" --organization "$ORG" --async
# promote it to stage dev
hammer content-view version promote --content-view "cv-app-docker" --organization "$ORG" --async --to-lifecycle-environment DEV
# NOTE: we can not promote it to the next stage (QA) until promotion to DEV is running
# TODO: figure out how we can schedule the 2nd promotion in background waiting on finishing the first one




###################################################################################################
#
# CCV Core Build + docker-host 
# 
###################################################################################################





###################################################################################################
#
# CCV Core Build + wordpress
# 
###################################################################################################

#                hammer content-view create \\
#                                        --name "ccv-${APP}" \\
#                                        --composite \\
#                                        --description "${APP} Composite Content View" \\
#                                        --organization "${ORG}"
#                                        --repositories "cv-os-rhel-7Server,cv-app-${APP}"

#                hammer content-view  publish --name "ccv-${APP}" --organization "$ORG" --async




