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

# function calls

import_gpg_keys()
create_sync_plans()


create_lifecycle_envs()
create_content_views()

# FUNCTIONS

def import_gpg_keys (
	# to ensure that our example rpms will work we do not create but download and use the GPG key we've created for the reference architecture
	# additionally we download and import the gpg keys for EPEL, VMware (R) tools and bareos (R) backup management software
	wget -O /tmp/EPEL7.key https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 
	wget -O /tmp/EPEL6.key https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
	hammer gpg create --name 'GPG-EPEL7' --organization "$ORG" --key /tmp/EPEL7.key
	hammer gpg create --name 'GPG-EPEL6' --organization "$ORG" --key /tmp/EPEL6.key
)

def create_sync_plans (
	# daily sync plan
	hammer sync-plan create --name 'daily sync at 3 a.m.' --description 'A daily sync plans runs every morning a 3 a.m.' --enabled=true --interval daily --organization "$ORG" --sync-date '2015-04-15 03:00:00'

)

def create_lifecycle_envs (
	# create the generic lifecycle env path
	hammer lifecycle-environment create --organization "$ORG" --name "DEV" --description "development" --prior "Library"
	hammer lifecycle-environment create --organization "$ORG" --name "QA" --description "Quality Assurance" --prior "DEV"
	hammer lifecycle-environment create --organization "$ORG" --name "PROD" --description "Production" --prior "QA"

	# created dedicated lifecycle env paths for our example applications
	# TODO
)


def create_content_views (
	hammer content-view create --name "cv-os-rhel-6Server" --description "RHEL Server 6 Core Build Content View" --organization "$ORG"
	hammer content-view  publish --name "cv-os-rhel-6Server" --organization "$ORG" --async
	# TODO figure out repo IDs
	hammer content-view update --organization "$ORG" --name "cv-os-rhel-6Server" --repository-ids 456,450,451,457

	# RHEL7
	hammer content-view create --name "cv-os-rhel-7Server" --description "RHEL Server 7 Core Build Content View" --organization "$ORG"
	hammer content-view  publish --name "cv-os-rhel-7Server" --organization "$ORG" --async
	# TODO figure out repo IDs
	hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-7Server" --repository-ids 452,453,454,455

	# CV wordpress (contains EPEL7 + Filter)
	hammer content-view create --name "cv-app-wordpress" --description "Wordpress Content View" --organization "$ORG"
	hammer content-view add-repository --organization "$ORG" --repository 'EPEL 7 - x86_64' --name "cv-app-wordpress" --product 'EPEL'
	hammer content-view filter create --type rpm --name 'wordpress-packages-only' --description 'Only include the wordpress rpm package' --inclusion=true --organization "$ORG" --repositories 'EPEL 7 - x86_64' --content-view "cv-app-wordpress"
	hammer content-view  publish --name "cv-app-wordpress" --organization "$ORG" --async
)
