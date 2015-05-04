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


# after the long-duration tasks have been done using soe-prep-setup.sh we now can run all remaining steps
DIR="$PWD"

# successfully tested
sh "${DIR}/step3.sh"
sh "${DIR}/step4.sh"

# TODO after testing it comment it out

#sh "${DIR}/step5.sh"
#sh "${DIR}/step6.sh"
#sh "${DIR}/step7.sh"
#sh "${DIR}/step8.sh"
#sh "${DIR}/step9.sh"
#sh "${DIR}/step10.sh"

