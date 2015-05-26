#! /bin/bash

#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 

# TODO short desc and outcome of this step

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

DIR="$PWD"
source "${DIR}/common.sh"


# create the generic lifecycle env path
hammer lifecycle-environment create --organization "$ORG" --name "DEV" --description "development" --prior "Library"
hammer lifecycle-environment create --organization "$ORG" --name "QA" --description "Quality Assurance" --prior "DEV"
hammer lifecycle-environment create --organization "$ORG" --name "PROD" --description "Production" --prior "QA"

# create the dedicated lifecycle env path for amce-web
hammer lifecycle-environment create --organization "$ORG" --name "Web-DEV" --description "development" --prior "Library"
hammer lifecycle-environment create --organization "$ORG" --name "Web-QA" --description "Quality Assurance" --prior "Web-DEV"
hammer lifecycle-environment create --organization "$ORG" --name "Web-UAT" --description "Production" --prior "Web-QA"
hammer lifecycle-environment create --organization "$ORG" --name "Web-PROD" --description "Production" --prior "Web-UAT"

# create the dedicated lifecycle env path for amce-shop
# TODO if we finally remove the shop we can remove this LC ENV path as well temporarily commented it out
#hammer lifecycle-environment create --organization "$ORG" --name "Shop-DEV" --description "development" --prior "Library"
#hammer lifecycle-environment create --organization "$ORG" --name "Shop-QA" --description "Quality Assurance" --prior "Shop-DEV"
#hammer lifecycle-environment create --organization "$ORG" --name "Shop-PROD" --description "Production" --prior "Shop-QA"
