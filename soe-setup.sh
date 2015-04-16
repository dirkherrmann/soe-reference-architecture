#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 

# latest version in github: TODO


# CONFIG

# Satellite 6 server and admin credentials
export SATELLITE_SERVER=""
export SATELLITE_USER=""
export SATELLITE_PASSWORD=""

# org name
export ORG="ACME"

# path to subscription manifest
export subscription_manifest_loc="/tmp/manifest.zip"

# additional RH repos 2 sync
# we've already defined a comprehensive set of RH repos we're syncing per default as defined inside the function
# please define here only additional RH repositories you want to sync
export additional_rh_repos_to_sync=""

# function calls
create_hammer_config()
create_org()
upload_manifest()
rh_repo_sync()
import_gpg_keys()

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

)

def rh_repo_sync (
	hammer repository-set enable  --organization "$ORG" --product "Red Hat Enterprise Linux Server" --name "Red Hat Enterprise Linux 6 Server (Kickstart)" --releasever "6.6" --basearch "x86_64" 
	# TODO additional repos 2 sync as defined in CONFIG section
	echo "TODO"

)

def import_gpg_keys (
	# to ensure that our example rpms will work we do not create but download and use the GPG key we've created for the reference architecture
	# additionally we download and import the gpg keys for VMware (R) tools and bareos (R) backup management software
	echo "TODO"

)
def create_products (
	echo "TODO"

)

def create_lifecycle_envs (
	hammer lifecycle-environment create --organization "ACME" --name "DEV" --description "development" --prior "Library"
	hammer lifecycle-environment create --organization "ACME" --name "QA" --description "Quality Assurance" --prior "DEV"
	hammer lifecycle-environment create --organization "ACME" --name "PROD" --description "Production" --prior "QA"

)


def create_content_views (
	hammer content-view create --name "cv-os-rhel-6Server" --description "RHEL Server 6 Core Build Content View" --organization "ACME"
	hammer content-view  publish --name "cv-os-rhel-6Server" --organization "ACME" --async
	# TODO figure out repo IDs
	hammer content-view update --organization "ACME" --name "cv-os-rhel-6Server" --repository-ids 456,450,451,457

	# RHEL7
	hammer content-view create --name "cv-os-rhel-7Server" --description "RHEL Server 7 Core Build Content View" --organization "ACME"
	hammer content-view  publish --name "cv-os-rhel-7Server" --organization "ACME" --async
	# TODO figure out repo IDs
	hammer content-view update --organization "ACME" --name "cv-os-rhel-7Server" --repository-ids 452,453,454,455

)
