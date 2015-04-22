# all prep steps which require a huge amount of time to run

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture


# check if exists and if yes source the config file 
if  $(test -f '~/.soe-config' )
then
	source '~/.soe-config'
else
	echo "Could not find configuration file. Please copy the example file into your home directory and adapt it accordingly!"
	echo "# cp <path to your github copy>/soe-reference-architecture/soe-config.example ~/.soe-config"
	exit 1
fi


# check if organization already exists. if yes, exit
hammer organization info --name $ORG >/dev/null 2>&1 && echo "Organization $ORG already exists. Exit."; exit 1

# this functions creates the yaml configuration file for hammer usage

# don't know why but it does not work... TODO 

#mkdir  ~/.hammer  
#cat << EOF > ~/.hammer/cli_config.yml  
#	:foreman:  
#	:host: $SATELLITE_SERVER
#	:username: $SATELLITE_USER
#	:password: $SATELLITE_PASSWD  
#	:organization: $ORG
#EOF 

# create org
hammer organization create --name "$ORG" --label "$ORG" --description "SOE Reference Architecture example org"

# upload manifest
hammer subscription upload --organization "$ORG" --file "$subscription_manifest_loc"
# note: has worked for me only at the second try, so maybe we should check if successful before proceeding:
hammer subscription list --organization $ORG | grep -q 'Red Hat Enterprise Linux Server' && echo ok || echo "Subscription import has not been successful. Exit"; exit

# create sync plan for daily sync
hammer sync-plan create --name 'daily sync at 3 a.m.' --description 'A daily sync plans runs every morning a 3 a.m.' --enabled=true --interval daily --organization "$ORG" --sync-date '2015-04-15 03:00:00'

# RHEL7 repos
hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (Kickstart)'  
hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server (RPMs)'  
hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'Red Hat Enterprise Linux 7 Server - RH Common (RPMs)'  
hammer repository-set enable --organization $ORG --product 'Red Hat Enterprise Linux Server' --basearch='x86_64' --releasever='7Server' --name 'RHN Tools for Red Hat Enterprise Linux 7 Server (RPMs)'  

# TODO do we need additional channels for Sat 6.1 (satellite-tools?)

# RHEL6 repos only if RHEL6_ENABLED param is set to 1 in config file
if [ "$RHEL6_ENABLED" -eq 1 ]
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

# Bareos Backup Management Software repository sync
hammer product create --name='Bareos-Backup-RHEL6' --organization="$ORG"
hammer product create --name='Bareos-Backup-RHEL7' --organization="$ORG"
hammer repository create --name='Bareos-RHEL7-x86_64' --organization="$ORG" --product='Bareos-Backup-RHEL7' --content-type='yum' --publish-via-http=true --url=http://download.bareos.org/bareos/release/latest/RHEL_7/
# TODO check what happens here since Bareos is using the same RHEL6 repo for both i686 and x86_64
hammer repository create --name='Bareos-RHEL6-x86_64' --organization="$ORG" --product='Bareos-Backup-RHEL6' --content-type='yum' --publish-via-http=true --url=http://download.bareos.org/bareos/release/latest/RHEL_6/
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "Bareos-Backup-RHEL6"
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "Bareos-Backup-RHEL7"
hammer repository synchronize --organization "$ORG" --product "Bareos-Backup-RHEL6" --async
hammer repository synchronize --organization "$ORG" --product "Bareos-Backup-RHEL7" --async

# TODO additional repos 2 sync as defined in CONFIG section


# EPEL product including RHEL7 and RHEL6 (optional) repositories <- NOT POSSIBLE DUE TO 2 DIFFERENT GPG KEYS!
hammer product create --name='EPEL7' --organization="$ORG"
# it seems that Sat6 can not handle the mirroring of EPEL repo. if it does not work use a static mirror from http://mirrors.fedoraproject.org/publiclist/EPEL/7/x86_64/ instead,like
# hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7' --content-type='yum' --publish-via-http=true --url= http://ftp-stud.hs-esslingen.de/pub/epel/7/x86_64/
hammer repository create --name='EPEL7-x86_64' --organization="$ORG" --product='EPEL7' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "EPEL7"

# EPEL Repo for RHEL6 repos only if EPEL6_ENABLED param is set to 1 in config file
if [ "$EPEL6_ENABLED" -eq 1 ]
then
	hammer product create --name='EPEL6' --organization="$ORG"
	hammer repository create --name='EPEL6-x86_64' --organization="$ORG" --product='EPEL6' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/6/x86_64/
	hammer repository synchronize --organization "$ORG" --product "EPEL6" --async
	# add it to daily sync plan
	hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' --organization $ORG --name  "EPEL6"
fi

# enable and sync OSE3 repositories
# TODO
echo "TODO" 

if [ "$PUPPETFORGE_ENABLED" -eq 1 ]
then
	# TODO check if we really need the entire repo or just selected modules from it
	# puppet forge repo
	hammer product create --name='Forge' --organization=$ORG
	hammer repository create --name='Puppet Forge' --organization=$ORG --product='Forge' --content-type='puppet' --publish-via-http=true --url=https://forge.puppetlabs.com
fi

