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


DIR="$PWD"
source "${DIR}/common.sh"

################################################################################################################
#
# CONFIGURATION SECTION
#
################################################################################################################
# Satellite 6 server
# Satellite 6 admin User
# Satellite 6 Password
# Satellite 6 Organization
export ORG="ACME"

# even if not recommended some customers are using a particular minor release of RHEL instead of 7Server
# the following option must be either set to "7Server" or to a particular minor release, e.g. "7.1"
export RHEL_RELEASE="7Server"

# Christoph defines the list of all container images we need
# Link: https://github.com/RHsyseng/OSE3-Sat6-RefImpl/blob/master/list_of_docker_images.asciidoc
export CONTAINER_IMAGES="
registry.access.redhat.com/rhel7.1
registry.access.redhat.com/rhel
registry.access.redhat.com/openshift3/ose-docker-registry
registry.access.redhat.com/openshift3/ose-pod
registry.access.redhat.com/openshift3/ose-sti-builder
registry.access.redhat.com/openshift3/ose-docker-builder
registry.access.redhat.com/openshift3/ose-deployer
registry.access.redhat.com/openshift3/mongodb-24-rhel7
registry.access.redhat.com/openshift3/mysql-55-rhel7
registry.access.redhat.com/openshift3/postgresql-92-rhel7
registry.access.redhat.com/jboss-eap-6/eap-openshift
registry.access.redhat.com/jboss-amq-6/amq-openshift
registry.access.redhat.com/jboss-webserver-3/tomcat7-openshift
registry.access.redhat.com/jboss-webserver-3/tomcat8-openshif
registry.access.redhat.com/openshift3/python-33-rhel7
registry.access.redhat.com/openshift3/nodejs-010-rhel7
registry.access.redhat.com/openshift3/ruby-20-rhel7
registry.access.redhat.com/openshift3/perl-516-rhel7
registry.access.redhat.com/openshift3/php-55-rhel7
registry.hub.docker.com/openshift/jenkins-1-centos7
"

################################################################################################################
# STEP 1
################################################################################################################

# TODO check if we can use the license manager role from Step 8 here

# check if subscription manifest contains OSE3 subscriptions
if $(hammer subscription list --organization "$ORG" | cut -d'|' -f1 | grep -q "OpenShift Enterprise Broker Infrastructure"); 
then 
	echo "Required Subscription already there"; 
else 
	echo "ERROR: Required Subscription for OpenShift Enterprise not in your Satellite 6 Organization yet."
	echo "Follow the instruction here to generate a new manifest:" # TODO and use the license mgr role for this task
	exit 1
fi

# assuming that the subscription manifest has been updated in the Red Hat customer portal
# we use the license manager role created during step 8 of the SOE solution guide
# TODO check if the role exist
hammer -u licensemgr -p 'xD6ZuhJ8' subscription  refresh-manifest --organization ACME


################################################################################################################
# STEP 3
################################################################################################################

# OpenShift 3 RPM repository: check if the repository already exist and enable and sync if not
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


# Container Image Import to Satellite 6 
# taken from Summit Lab script
# create a container product
hammer product create --name='Container Images' \
   --organization="$ORG"

## single repo manual approach, substituted by for loop below
## create image repo for RHEL
#hammer repository create --name='rhel-base' \
#   --product='Container Images' --content-type='docker' \
#   --url='https://registry.access.redhat.com' \
#   --docker-upstream-name='rhel' \
#   --publish-via-http="true" \
#   --organization="$ORG"



# TODO registry.access.redhat.com/openshift3/mongodb-24-rhel7:latest
# <goern> registry.access.redhat.com/jboss-eap-6/eap-openshift:6.4 
# since we have a long list of images we need we are using a loop
for image in $CONTAINER_IMAGES
do
	# divide between registry and upstream repo name
	REGISTRY_URL=$(echo $image | cut -d'/' -f1)
	REPO_NAME=$(echo $image | cut -d'/' -f2-)
	echo "Adding REPO: $REPO_NAME REGISTRY: $REGISTRY_URL "

	hammer repository create --name="${REPO_NAME}" \
 	  --product='Container Images' --content-type='docker' \
 	  --url="https://${REGISTRY_URL}" \
 	  --docker-upstream-name="${REPO_NAME}" \
 	  --publish-via-http="true" \
	  --organization="$ORG"
done

# create image repo for Tomcat7
#hammer repository create --name='openshift3/postgresql-92-rhel7' \
#   --product='Container Images' --content-type='docker' \
#   --url='https://registry.access.redhat.com' \
#   --docker-upstream-name='openshift3/postgresql-92-rhel7' \
#   --publish-via-http="true" \
#   --organization="$ORG"

#hammer repository create --name='rh-tomcat7-openshift' \
#   --product='Container Images' --content-type='docker' \
#   --url='https://registry.access.redhat.com' \
#   --docker-upstream-name='jboss-webserver-3/tomcat7-openshift' \
#   --publish-via-http="true" \
#   --organization="$ORG"


# Sync the images
hammer product synchronize --name "Container Images" \
   --organization "$ORG"

# add the container images product to our sync plan created in Step 3
hammer product set-sync-plan --sync-plan 'daily sync at 3 a.m.' \
   --name 'Container Images' --organization "$ORG" 

hammer content-view create --name "cv-con-webshop" \
   --description "CV of type container images for ACME Webshop" \
   --organization "$ORG"

hammer content-view add-repository --name "cv-con-webshop" \
   --repository "rhel-base" --product "Container Images" \
   --organization "$ORG"

#hammer content-view add-repository --organization "$ORG" --name "registry" --repository "mysql" --product "containers"
#hammer content-view add-repository --organization "$ORG" --name "registry" --repository "wordpress" --product "containers"

hammer content-view publish --name "cv-con-webshop" \
   --organization "$ORG"

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

# TODO check if we can use the app owner role from Step 8 here or introduce a new one

# assemble together with existing Core Build content view created during step 5
# Note: this requires common.sh script if you running this script standalone
# get the lastest version of our RHEL7 core build and exit if unsuccessful
export RHEL7_CB_VID=`get_latest_version cv-os-rhel-7Server`
if [ -z ${RHEL7_CB_VID} ]
then 
	echo "Could not identify latest CV version id of RHEL 7 Core Build. Exit."; exit; 
else 

	echo "Identified VERSION ID ${RHEL7_CB_VID} as most current version of our RHEL7 Core Build"
fi

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


################################################################################################################
# STEP 8
################################################################################################################

# we introduce new role here: 
# 	oseadmin who manages the OSE3 infrastructure
#	appadmin who manages the container images supposed to run on top of OpenShift
# we create 4 users associated to 2 groups associated to these 2 roles


# oseadmin supposed to manage content inside a synched registry
# but not allowed to edit or change a registry -> #166 view_registries DockerRegistry
hammer user create --firstname itops \
   --lastname platformops1 \
   --login itopsplatformops1 \
   --mail root@localhost.localdomain \
   --password 'redhat' \
   --auth-source-id='1'  \
   --organizations ${ORG}

hammer role create --name itops-platform-ops
hammer user add-role --login itopsplatformops1 --role itops-platform-ops

# view_hosts
hammer filter create --permission-ids 74 --role itops-platform-ops
#  
