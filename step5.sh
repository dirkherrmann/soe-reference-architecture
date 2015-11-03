#! /bin/bash

#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 

# TODO short desc and outcome of this step

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

DIR="$PWD"
source "${DIR}/common.sh"

###################################################################################################
#
# RHEL 6 Core Build Content View
#
###################################################################################################
if [ "$RHEL6_ENABLED" -eq 1 ]
then
	hammer content-view create --name "cv-os-rhel-6Server" \
	   --description "RHEL Server 6 Core Build Content View" \
	   --organization "$ORG"

	# software repositories
	hammer content-view add-repository --organization "$ORG" \
	   --name "cv-os-rhel-6Server" \
	   --repository 'Red Hat Enterprise Linux 6 Server Kickstart x86_64 6.5' \
	   --product 'Red Hat Enterprise Linux Server'

	hammer content-view add-repository \
	   --organization "$ORG" \
	   --name "cv-os-rhel-6Server" \
	   --repository 'Red Hat Enterprise Linux 6 Server RPMs x86_64 6.5' \
	   --product 'Red Hat Enterprise Linux Server'

	# there is an inconsistency here between RHEL7 and RHEL6: RHEL6 repo name without 6Server at the end 
	hammer content-view add-repository --organization "$ORG" \
	   --name "cv-os-rhel-6Server" \
	   --repository 'Red Hat Satellite Tools 6.1 for RHEL 6 Server RPMs x86_64' \
	   --product 'Red Hat Enterprise Linux Server'

	hammer content-view add-repository --organization "$ORG" \
	   --name "cv-os-rhel-6Server" \
	   --repository 'Zabbix-RHEL6-x86_64' \
	   --product 'Zabbix-Monitoring'

	hammer content-view add-repository --organization "$ORG" \
	   --name "cv-os-rhel-6Server" \
	   --repository 'Bareos-RHEL6-x86_64' \
	   --product 'Bareos-Backup-RHEL6'

	# exclude filter example using emacs package
	# due to https://bugzilla.redhat.com/show_bug.cgi?id=1228890 you need to provide
	# repository ID instead of name otherwise the filter applies to all repos 
	REPOID=$(hammer --csv repository list --name 'Red Hat Enterprise Linux 6 Server RPMs x86_64 6.5' \
	   --organization $ORG | grep -vi '^ID' | awk -F',' '{print $1}')

	hammer content-view filter create --type rpm \
	   --name 'excluding-emacs' --description 'Excluding emacs package' \
	   --inclusion=false --organization "$ORG" --repository-ids ${REPOID} \
	   --content-view "cv-os-rhel-6Server"

	hammer content-view filter rule create --name 'emacs*' --organization "$ORG" \
	   --content-view "cv-os-rhel-6Server" --content-view-filter 'excluding-emacs'

	# add vmware tools and rhev agent repos
	hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-6Server" \
	   --repository 'VMware-Tools-RHEL6-x86_64' --product 'VMware-Tools-RHEL6'

	hammer content-view add-repository --organization "$ORG" --name "cv-os-rhel-6Server" \
	   --repository 'Red Hat Enterprise Virtualization Agents for RHEL 6 Server RPMs x86_64 6.5' \
	   --product 'Red Hat Enterprise Linux Server'

	# puppet modules which are part of core build 
	# Note: since all modules are RHEL major release independent we're adding the same modules as for RHEL 7 Core Build
	for module in 'motd' 'ntp' 'corebuildpackages' 'loghost' 'zabbix' 'vmwaretools' 'rhevagent'
	do
		hammer content-view puppet-module add --name ${module} \
		   --content-view cv-os-rhel-6Server \
		   --organization $ORG
	done

	# CV publish without --async option to ensure that the CV is published before we create CCVs in the next step
	hammer content-view  publish --name "cv-os-rhel-6Server" --organization "$ORG" 	
fi
###################################################################################################
#
# RHEL7 Core Build Content View
#
###################################################################################################
hammer content-view create --name "cv-os-rhel-7Server" \
   --description "RHEL Server 7 Core Build Content View" --organization "$ORG"

# software repositories
hammer content-view add-repository --organization "$ORG" \
   --name "cv-os-rhel-7Server" \
   --repository 'Red Hat Enterprise Linux 7 Server Kickstart x86_64 7Server' \
   --product 'Red Hat Enterprise Linux Server'

hammer content-view add-repository --organization "$ORG" \
   --name "cv-os-rhel-7Server" \
   --repository 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server' \
   --product 'Red Hat Enterprise Linux Server'

hammer content-view add-repository --organization "$ORG" \
   --name "cv-os-rhel-7Server" \
   --repository 'Red Hat Satellite Tools 6.1 for RHEL 7 Server RPMs x86_64' \
   --product 'Red Hat Enterprise Linux Server'

#Using Satellite Beta Tools Repository now
#hammer content-view add-repository --organization "$ORG" \
#   --name "cv-os-rhel-7Server" \
#   --repository 'Red Hat Enterprise Linux 7 Server - RH Common RPMs x86_64 7Server' \
#   --product 'Red Hat Enterprise Linux Server'

hammer content-view add-repository --organization "$ORG" \
   --name "cv-os-rhel-7Server" \
   --repository 'Zabbix-RHEL7-x86_64' \
   --product 'Zabbix-Monitoring'

hammer content-view add-repository --organization "$ORG" \
   --name "cv-os-rhel-7Server" \
   --repository 'Bareos-RHEL7-x86_64' \
   --product 'Bareos-Backup-RHEL7'

# exclude filter example using emacs package
# due to https://bugzilla.redhat.com/show_bug.cgi?id=1228890 you need to provide 
# repository ID instead of name otherwise the filter applies to all repos 
REPOID=$(hammer --csv repository list --name 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server' \
   --organization $ORG | grep -vi '^ID' | awk -F',' '{print $1}')

hammer content-view filter create --type rpm --name 'excluding-emacs' \
   --description 'Excluding emacs package' --inclusion=false \
   --organization "$ORG" --repository-ids ${REPOID} \
   --content-view "cv-os-rhel-7Server"

hammer content-view filter rule create --name 'emacs*' \
   --organization "$ORG" --content-view "cv-os-rhel-7Server" \
   --content-view-filter 'excluding-emacs'

# we are creating an initial version just containing RHEL 7.0 bits based on a date filter between RHEL 7.0 GA and before RHEL 7.1 GA
# TODO currently we can't update or delete the filter without UI since option list does not work. commenting the filter out until it works
#hammer content-view filter create --type erratum --name 'rhel-7.0-only' --description 'Only include RHEL 7.0 bits' --inclusion=true --organization "$ORG" --repositories 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server' --content-view "cv-os-rhel-7Server"
#hammer content-view filter rule create  --organization "$ORG" --content-view "cv-os-rhel-7Server" --content-view-filter 'rhel-7.0-only' --start-date 2014-06-09 --end-date 2015-03-01 --types enhancement,bugfix,security

# download and push into custom puppet repo the puppetlabs modules we need
wget -O /tmp/puppetlabs-stdlib-4.6.0.tar.gz https://forgeapi.puppetlabs.com/v3/files/puppetlabs-stdlib-4.6.0.tar.gz

wget -O /tmp/puppetlabs-concat-1.2.3.tar.gz https://forgeapi.puppetlabs.com/v3/files/puppetlabs-concat-1.2.3.tar.gz

# add these modules to ACME puppet repo
hammer repository upload-content --organization "${ORG}" \
   --product ACME --name "ACME Puppet Repo" \
   --path /tmp/puppetlabs-stdlib-4.6.0.tar.gz

hammer repository upload-content --organization "${ORG}" \
   --product ACME --name "ACME Puppet Repo" \
   --path /tmp/puppetlabs-concat-1.2.3.tar.gz

# add all puppet modules which are part of core build
for module in 'motd' 'ntp' 'corebuildpackages' 'loghost' 'zabbix' 'vmwaretools' 'rhevagent' 'stdlib' 'concat'
do
	hammer content-view puppet-module add --name ${module} \
	   --content-view cv-os-rhel-7Server \
	   --organization "$ORG"
done	

# CV publish without --async option to ensure that the
# CV is published before we create CCVs in the next step
hammer content-view  publish --organization "$ORG" \
   --name "cv-os-rhel-7Server" 


# TODO now create a new version of cv including all erratas until today (removing the date filter created earlier)


# promote core build CVs from Library to DEV, QA, PROD
export RHEL7_CB_VID=`get_latest_version cv-os-rhel-7Server`
export RHEL7_CVID=$(hammer --csv content-view list --name cv-os-rhel-7Server --organization ${ORG} | grep -vi '^Content View ID,' | awk -F',' '{print $1}' )

if [ -z ${RHEL7_CB_VID} ]
then 
	echo "Could not identify latest CV version id of RHEL 7 Core Build. Exit."; exit; 
else 

	echo "Identified VERSION ID ${RHEL7_CB_VID} as most current version of our RHEL7 Core Build."
	echo " Promoting it now to DEV, QA and PROD. This will take a while."
	hammer content-view version promote --organization "$ORG" \
	   --content-view-id $RHEL7_CVID  \
	   --to-lifecycle-environment DEV \
	   --id $RHEL7_CB_VID

	hammer content-view version promote --organization "$ORG" \
	   --content-view-id $RHEL7_CVID  \
	   --to-lifecycle-environment QA \
	   --id $RHEL7_CB_VID

	hammer content-view version promote --organization "$ORG" \
	   --content-view-id $RHEL7_CVID  \
	   --to-lifecycle-environment PROD \
	   --id $RHEL7_CB_VID

	hammer content-view version promote --organization "$ORG" \
	   --content-view-id $RHEL7_CVID  \
	   --to-lifecycle-environment Web-DEV \
	   --id $RHEL7_CB_VID

	hammer content-view version promote --organization "$ORG" \
	   --content-view-id $RHEL7_CVID  \
	   --to-lifecycle-environment Web-QA \
	   --id $RHEL7_CB_VID

	hammer content-view version promote --organization "$ORG" \
	   --content-view-id $RHEL7_CVID  \
	   --to-lifecycle-environment Web-UAT \
	   --id $RHEL7_CB_VID

	hammer content-view version promote --organization "$ORG" \
	   --content-view-id $RHEL7_CVID  \
	   --to-lifecycle-environment Web-PROD \
	   --id $RHEL7_CB_VID
fi

# since we need our core build CV IDs more than once let's use variables for them
# note: we don't need to CV IDs but the VERSION IDs of most current versions for our CCV creation
if [ "$RHEL6_ENABLED" -eq 1 ]
then
	export RHEL6_CB_VID=`get_latest_version cv-os-rhel-6Server`
	export RHEL6_CVID=$(hammer --csv content-view list --name cv-os-rhel-6Server \
	   --organization ${ORG} | grep -vi '^Content View ID,' | awk -F',' '{print $1}' )

	echo "Identified VERSION ID ${RHEL6_CB_VID} as most current version of our RHEL6 Core Build."
	echo "Promoting it now to DEV, QA and PROD. This might take a while."
	hammer content-view version promote --content-view-id $RHEL6_CVID  \
	   --organization "$ORG" --to-lifecycle-environment DEV --id $RHEL6_CB_VID
	hammer content-view version promote --content-view-id $RHEL6_CVID  \
	   --organization "$ORG" --to-lifecycle-environment QA --id $RHEL6_CB_VID
	hammer content-view version promote --content-view-id $RHEL6_CVID  \
	   --organization "$ORG" --to-lifecycle-environment PROD --id $RHEL6_CB_VID 
fi


