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

hammer lifecycle-environment create --organization "$ORG" --name "Shop-DEV" --description "development" --prior "Library"
hammer lifecycle-environment create --organization "$ORG" --name "Shop-QA" --description "Quality Assurance" --prior "Shop-DEV"
hammer lifecycle-environment create --organization "$ORG" --name "Shop-PROD" --description "Production" --prior "Shop-QA"
