#! /bin/bash

#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 

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
