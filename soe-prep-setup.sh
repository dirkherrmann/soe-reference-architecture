# all prep steps which require a huge amount of time to run

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

# TODO make this script interactive to ask for each value and then automatically create the config file based on our template


DIR="$PWD"
source "${DIR}/common.sh"


# basically all long-duration tasks are now executed during step 1 and step 2
DIR="$PWD"
sh "${DIR}/step1.sh" && sh "${DIR}/step2.sh"

