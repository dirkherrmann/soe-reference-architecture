# This script is cleaning up the entire demo organization and all entities

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture


# check if exists and if yes source the config file 
if [ -f ~/.soe-config ];
then
	source ~/.soe-config
else
	echo "Could not find configuration file. Please copy the example file into your home directory and adapt it accordingly!"
	echo "# cp <path to your github copy>/soe-reference-architecture/soe-config.example ~/.soe-config"
	exit 1
fi

# TODO this script can create a lot of damage. we have to ask if the user really wants to destroy the current organization with all its elements

# remove content views
for i in $(hammer --csv content-view list --full-results 1 --organization "$ORG" |  grep -e "^[0-9]*,.*" | awk -F, {'print $1'} )
do 
	echo "Deleting content view ID $i";
	# TOOD does not work, we need to remove from all envs before
	# hammer content-view delete --id $i
done


# delete gpg keys

# delete sync plan

# delete products
# TODO does not work, at least it has successfully deleted repositories but then ran into a candlepin issue: hammer product delete --name 'Bareos-Backup' --organization $ORG
# Error message foreman task: http://pastebin.test.redhat.com/278203
# After resuming the task it has completed successfully

