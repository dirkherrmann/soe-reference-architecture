#!/bin/bash
# 
# This script configures Red Hat Satellite 6 to install and configure an OpenShift Enterprise 3 environment.
#
# It is used in multiple documentations from Red Hat Systems Engineering, for example:
# 
# - 10 Steps to Build an SOE Solution Guide: https://access.redhat.com/articles/1585273 (Step 9)
# - OpenShift Enterprise
#
#
# The full text documentation to this script could be found here:
# 
#
# TODO GSS Support Disclaimer
#
################################################################################################################
#
# CONFIGURATION SECTION
#
################################################################################################################
# Satellite 6 server
# Satellite 6 User
# Satellite 6 Password
# Satellite 6 Organization
export ORG="ACME"

# even if not recommended some customers are using a particular minor release of RHEL instead of 7Server
# the following option must be either set to "7Server" or to a particular minor release, e.g. "7.1"
export RHEL_RELEASE="7Server"


################################################################################################################
# STEP 1
################################################################################################################

# check if subscription manifest contains OSE3 subscriptions
if $(hammer subscription list --organization "$ORG" | cut -d'|' -f1 | grep -q "OpenShift Enterprise Broker Infrastructure"); 
then 
	echo "Required Subscription already there"; 
else 
	echo "ERROR: Required Subscription for OpenShift Enterprise not in your Satellite 6 Organization yet."
	echo "Follow the instruction here to generate a new manifest:" # TODO and use the license mgr role for this task
	exit 1
fi


################################################################################################################
# STEP 3
################################################################################################################

# check if the repository already exist and enable and sync if not
if $(hammer --output csv repository list --organization "$ORG" --per-page 500 | cut -d',' -f2 | grep -q 'Red Hat OpenShift Enterprise 3.0 RPMs'); 
then 
	echo "The OpenShift Enterprise RPM Repository is already there. Skipping enabling it."; 
else 
	echo "The OpenShift Enterprise RPM Repository is not enabled yet. Enabling it now"; 
	hammer repository-set enable --organization "$ORG" \
	   --product 'Red Hat OpenShift Enterprise' \
	   --basearch='x86_64' --releasever="$RHEL_RELEASE" \
	   --name 'Red Hat OpenShift Enterprise 3.0 (RPMs)'
fi

# OpenShift additionally requires Extras and Optional channel.
# the repository already exist and enable and sync if not
# check if the repository already exist and enable and sync if not
if $(hammer --output csv repository list --organization "$ORG" --per-page 500 | cut -d',' -f2 | grep -q 'Red Hat Enterprise Linux 7 Server - Extras RPMs x86_64'); 
then 
	echo "The RHEL Extras RPM Repository is already there. Skipping enabling it."; 
else 
	echo "The  RHEL Extras RPM Repository is not enabled yet. Enabling it now"; 
	hammer repository-set enable --organization "$ORG" \
	   --product 'Red Hat Enterprise Linux Server' \
	   --basearch='x86_64' --releasever="$RHEL_RELEASE" \
	   --name 'Red Hat Enterprise Linux 7 Server - Extras (RPMs)'
fi

if $(hammer --output csv repository list --organization "$ORG" --per-page 500 | cut -d',' -f2 | grep -q 'Red Hat Enterprise Linux 7 Server - Optional RPMs x86_64'); 
then 
	echo "The RHEL Optional RPM Repository is already there. Skipping enabling it."; 
else 
	echo "The  RHEL Optional RPM Repository is not enabled yet. Enabling it now"; 
	hammer repository-set enable --organization "$ORG" \
	   --product 'Red Hat Enterprise Linux Server' \
	   --basearch='x86_64' --releasever="$RHEL_RELEASE" \
	   --name 'Red Hat Enterprise Linux 7 Server - Optional (RPMs)'
fi


# add OSE3 repository to our daily sync plan
# Note: we assume that the RHEL product has been already added to this sync plan
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' \
   --name 'Red Hat OpenShift Enterprise' --organization "$ORG" 

# sync OSE3 repository (let's do it always to ensure we have the latest version')
hammer repository synchronize --organization "$ORG" \
   --product 'Red Hat OpenShift Enterprise'

# sync RHEL product including all repos to ensure we have the lastest version
hammer repository synchronize --organization "$ORG" \
   --product 'Red Hat Enterprise Linux Server'


################################################################################################################
# STEP 6
################################################################################################################
# create a content view consisting of OpenShift, Extras and Optional Channel plus Puppet Modules
# Note: in our setup neither Extras nor Optional are part of the Core Build CV.
# For further details see Step 5: Define your Core Build in the doc "10 Steps to Build an SOE"

# currently there is only one module, TODO check if we need more than this one

# TODO import our Puppet modules from Github
for module in 'ose3prerequisites' # 'ose3-node' 'ose3-master'
do
	# download the module from Github
	# TODO decide how we want to deal with the version of the module, also provider (RHsyseng)
	wget -O /tmp/${module}.tar.gz https://forgeapi.puppetlabs.com/v3/files/RHsyseng-${module}-0.1.5.tar.gz

	# push the module to Satellite 6
	hammer repository upload-content --organization "${ORG}" \
	   --product ACME --name "ACME Puppet Repo" \
	   --path /tmp/${module}.tar.gz

	# add the module to the content view (Note: has to be the module not file name)
	hammer content-view puppet-module add --name ${module} \
	   --content-view cv-app-ose3 \
	   --organization "$ORG"
done

# assemble together with existing Core Build content view created during step 5
# Note: this requires common.sh script if you running this script standalone
APP_CVID=`get_latest_version cv-app-ose3`
hammer content-view create --name "ccv-infra-ose3" \
   --composite --description "CCV for OpenShift Enterprise 3" \
   --organization $ORG --component-ids ${RHEL7_CB_VID},${APP_CVID}

# publish the CCV
hammer content-view publish --name "ccv-infra-ose3" \
   --organization "$ORG" 

# promote the CCV through our lifecycle environments
# TODO check if we really want to promote until Prod already
VID=`get_latest_version ccv-infra-ose3`
for ENV in Web-DEV Web-QA Web-UAT Web-PROD
do
  hammer content-view version promote --organization "$ORG" \
     --content-view "ccv-infra-ose3" \
     --to-lifecycle-environment ${ENV} \
     --id $VID 
done



################################################################################################################
# STEP 7
################################################################################################################

# OpenShift Enterprise 3 nodes require a second disk to store container images
# Therefore we create a new partition table with a second based on a clone of the existing one.

# TODO partition table

# TODO foreman hook to create the inventory file

# TODO host groups (hierarchy)

# TODO activation keys

# TODO sample command to provision a new host (node)
