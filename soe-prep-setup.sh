# all prep steps which require a huge amount of time to run

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
pre_check()
create_hammer_config()
create_org()
upload_manifest()
rh_repo_sync()
puppetforge_sync()
ose3_sync()

def pre_check (
	# check if organization already exists. if yes, exit
	hammer organization info --name $ORG >/dev/null 2>&1 || echo "Organization $ORG already exists. Exit."; exit 1

)


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

	# TODO do we need additional channels for Sat 6.1 (satellite-tools?)


	# RHEL6 repos only if RHEL6_ENABLED param is set to 1 in config file
	if $RHEL6_ENABLED == 1
	then
		
		hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server (Kickstart)'  
		hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server (RPMs)'  
		hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'Red Hat Enterprise Linux 6 Server - RH Common (RPMs)'  
		hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='6Server' --name 'RHN Tools for Red Hat Enterprise Linux 6 Server (RPMs)'  
  
	fi

	# sync all packages
	hammer product synchronize --organization $ORG --name  'Red Hat Enterprise Linux Server' --async

	# set sync plan
	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  'Red Hat Enterprise Linux Server' 


	# TODO check if we sync already the repos for 3rd party software here (EPEL, Bareos, VMware Tools)

	# TODO additional repos 2 sync as defined in CONFIG section
	echo "TODO"

)

def epel_sync (

	# EPEL product including RHEL7 and RHEL6 (optional) repositories <- NOT POSSIBLE DUE TO 2 DIFFERENT GPG KEYS!
	hammer product create --name='EPEL7' --organization="$ORG"
	hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/
	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "EPEL7"

	# EPEL Repo for RHEL6 repos only if EPEL6_ENABLED param is set to 1 in config file
	if $EPEL6_ENABLED == 1
	then
		hammer product create --name='EPEL6' --organization="$ORG"
		hammer repository create --name='EPEL6-x86_64' --organization="$ORG" --product='EPEL6' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/6/x86_64/
	hammer repository synchronize --organization "$ORG" --product "EPEL6" --async
		# add it to daily sync plan
		hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "EPEL6"
	fi
)

def ose3_sync (
	# enable and sync OSE3 repositories
	# TODO
	echo "TODO" 
)
def puppetforge_sync (
	if $PUPPETFORGE_ENABLED == 1
	then
		# TODO check if we really need the entire repo or just selected modules from it
		# puppet forge repo
		hammer product create --name='Forge' --organization=$ORG
		hammer repository create --name='Puppet Forge' --organization=$ORG --product='Forge' --content-type='puppet' --publish-via-http=true --url=https://forge.puppetlabs.com
	fi
)

