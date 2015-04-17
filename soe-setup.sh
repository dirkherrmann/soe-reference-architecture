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
create_hammer_config()
create_org()
upload_manifest()
rh_repo_sync()

wordpress_repo_sync()

import_gpg_keys()
create_sync_plans()

create_products()
create_lifecycle_envs()
create_content_views()

# FUNCTIONS
def create_hammer_config (
	echo "TODO"

)

def create_org (
	hammer organization create --name "$ORG" --label "$ORG" --description "SOE Reference Architecture example org"

)

def upload_manifest (
	hammer subscription upload --organization "$ORG" --file "$subscription_manifest_loc"
	# note: has worked for me only at the second try, so maybe we should check if successful before proceeding:
	hammer subscription list --organization ACME | grep -q 'Red Hat Enterprise Linux Server' && echo ok || echo "Subscription import has not been successful. Exit"

)

def rh_repo_sync (
	# RHEL7 repos
	hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (Kickstart)'  
	hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (RPMs)'  
	hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server - RH Common (RPMs)'  
	hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'RHN Tools for Red Hat Enterprise Linux 7 Server (RPMs)'  

	# RHEL6 repos
	hammer repository-set enable  --organization "$ORG" --product "Red Hat Enterprise Linux Server" --name "Red Hat Enterprise Linux 6 Server (Kickstart)" --releasever "6.6" --basearch "x86_64" 

	# sync all packages
	hammer product synchronize --organization $ORG --name  'Red Hat Enterprise Linux Server' --async

	# set sync plan
	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  'Red Hat Enterprise Linux Server' 


	# TODO check if we sync already the repos for 3rd party software here (EPEL, Bareos, VMware Tools)

	# TODO additional repos 2 sync as defined in CONFIG section
	echo "TODO"

)

def wordpress_repo_sync (
	# download wordpress
	# package and sign it
	# create a yum repo
	# create the Satellite 6 product and add our local repository
	hammer product create --name='wordpress' --organization="$ORG"
	# hammer repository create --name='wordpress' --organization="$ORG" --product='wordpress' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/6/x86_64/ 
)
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
def create_products (
	echo "TODO"
	# puppet forge repo
	hammer product create --name='Forge' --organization=$ORG
	hammer repository create --name='Puppet Forge' --organization=$ORG --product='Forge' --content-type='puppet' --publish-via-http=true --url=https://forge.puppetlabs.com

	# EPEL product including RHEL7 and RHEL6 (optional) repositories <- NOT POSSIBLE DUE TO 2 DIFFERENT GPG KEYS!
	hammer product create --name='EPEL7' --organization="$ORG"
	hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/
	# hammer product create --name='EPEL6' --organization="$ORG"
	# hammer repository create --name='EPEL6-x86_64' --organization="$ORG" --product='EPEL6' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/6/x86_64/
	hammer repository synchronize --organization "$ORG" --product "EPEL" --async
	# add it to daily sync plan
	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "EPEL"

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
