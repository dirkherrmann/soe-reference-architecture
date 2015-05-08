# all prep steps which require a huge amount of time to run

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

# TODO make this script interactive to ask for each value and then automatically create the config file based on our template


DIR="$PWD"
source "${DIR}/common.sh"

# check if exists and if yes source the config file 
if  $(test -f '~/.soe-config' )
then
	source '~/.soe-config'
else
	echo "Could not find configuration file. Please copy the example file into your home directory and adapt it accordingly!"
	echo "# cp <path to your github copy>/soe-reference-architecture/soe-config.example ~/.soe-config"
	exit 1
fi


# basically all long-duration tasks are now executed during step 1 and step 2
DIR="$PWD"
sh "${DIR}/step1.sh" && sh "${DIR}/step2.sh"


