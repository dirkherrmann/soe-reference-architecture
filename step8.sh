#! /bin/bash

#
# this script automatically does the setup documented in the reference architecture "10 steps to create a SOE"
# 

# TODO short desc and outcome of this step

# latest version in github: https://github.com/dirkherrmann/soe-reference-architecture

DIR="$PWD"
source "${DIR}/common.sh"

# Note: wildcards work only with ~ but not with ^: BZ TBD

# Note RBAC names are broken but IDs work: https://bugzilla.redhat.com/show_bug.cgi?id=1230884 

###################################################################################################
#
# ROLE 1: License Manager
#
###################################################################################################
hammer user create --firstname license \
   --lastname manager \
   --login licensemgr \
   --mail root@localhost.localdomain \
   --password 'xD6ZuhJ8' \
   --auth-source-id='1'  \
   --organizations ${ORG}

hammer role create --name license-mgr
hammer user add-role --login licensemgr --role license-mgr

# view_hosts
hammer filter create --permission-ids 74 --role license-mgr 
# view_reports
hammer filter create --permission-ids 124 --role license-mgr 
# view_products
hammer filter create --permission-ids 209 --role license-mgr 
# my_organizations,access_dashboard,view_statistics
hammer filter create --permission-ids 223,38,142 --role license-mgr 
# view_subscriptions,attach_subscriptions,unattach_subscriptions,import_manifest,delete_manifest
hammer filter create --permission-ids 214,215,216,217,218 --role license-mgr


 

###################################################################################################
#
# ROLE 2: foreman hook user
#
###################################################################################################

hammer user  create --firstname foreman --lastname hook --login foremanhook --mail root@localhost.localdomain --password 'xD6ZuhJ8' --auth-source-id="1" --organizations ${ORG}
hammer role create --name foremanhookrole

# view host group
# hammer filter create --permission-ids 70 --role foremanhookrole # permissions view_hostgroups

# view host 74
hammer filter create --permission-ids 74 --role foremanhookrole # permissions view_hosts

# view locations view_locations 87

# compute resource create 
#hammer filter create --permissions edit_compute_resources,create_compute_resources,view_compute_resources --role foremanhookrole
# hammer filter create --permission-ids 20 --role foremanhookrole # permissions edit_compute_resources
hammer filter create --permission-ids 19 --role foremanhookrole # permissions create_compute_resources
# hammer filter create --permission-ids 18 --role foremanhookrole # permissions view_compute_resources

hammer user add-role --login foremanhook --role foremanhookrole



###################################################################################################
#
# SYSENG TEAM
#
###################################################################################################

# TODO add --locations (comma separated) where it fits and disable mail

# OS SysEng users
hammer user create --firstname brett \
   --lastname syseng \
   --login brettsyseng \
   --mail brettsyseng@example.com \
   --password 'redhat' \
   --auth-source-id="1" \
   --organizations ${ORG}

hammer user create \
   --firstname mike \
   --lastname syseng \
   --login mikesyseng \
   --mail tomsyseng@example.com \
   --password 'redhat' \
   --auth-source-id="1" \
   --organizations ${ORG}

# create the syseng group and assign both users to it
hammer user-group create --name syseng-team
hammer user-group add-user --name syseng-team --user brettsyseng
hammer user-group add-user --name syseng-team --user mikesyseng

# create the syseng role and assign the qa group to it
hammer role create --name syseng
hammer user-group add-role --name syseng-team --role syseng

# add the predefined Manager role to this group
hammer user-group add-role --name syseng-team --role Manager

# Products create_products,edit_products,destroy_products,sync_products
hammer filter create --permission-ids 209,210,211,212,213 --role syseng

# FILTERED: view_content_views,create_content_views,edit_content_views,
# publish_content_views,promote_or_remove_content_views
hammer filter create --permission-ids 190,191,192,194,195 --search 'name ~ cv-os*' --role syseng 

# FILTERED: promote_or_remove_content_views_to_environments
hammer filter create --permission-ids 208 --search 'name ~ DEV' --role syseng

# view_lifecycle_environments
hammer filter create --permission-ids 204 --role syseng

# Puppetclass view_puppetclasses,create_puppetclasses,edit_puppetclasses
# destroy_puppetclasses,import_puppetclasses
hammer filter create --permission-ids 115,116,117,118,119 --role syseng


# not needed anymore: figure out the role ID of predefined manager role and assign it to syseng group
# MANAGERID=$(hammer --csv role list --search Manager | grep -e '[0-9]*,Manager$' | awk -F',' '{print $1}')

###################################################################################################
#
# APP SRV OWNER - SKIPPED
#
###################################################################################################

## App Srv Owners
#hammer user create \
#   --firstname joe \
#   --lastname appsrv \
#   --login joeappsrv \
#   --mail joeappsrv@example.com \
#   --password 'redhat' \
#   --auth-source-id="1" \
#   --organizations ACME


###################################################################################################
#
# QA ROLES
#
###################################################################################################

hammer user create --firstname jane \
   --lastname qa --login janeqa \
   --mail janeqa@example.com \
   --password 'redhat' \
   --auth-source-id='1' \
   --organizations ${ORG}

hammer user create --firstname tom \
   --lastname qa --login tomqa \
   --mail tomqa@example.com \
   --password 'redhat' \
   --auth-source-id='1' \
   --organizations ${ORG}

# create the qa group and assign both users to it
hammer user-group create --name qa-team
hammer user-group add-user --name qa-team --user janeqa
hammer user-group add-user --name qa-team --user tomqa

# create the qa role and assign the qa group to it
hammer role create --name qa-user
hammer user-group add-role --name qa-team --role qa-user


# view_environments,create_environments,edit_environments,destroy_environments,import_environments
hammer filter create --permission-ids 43,44,45,46,47 --role qa-user 
# view_tasks,view_statistics,access_dashboard
hammer filter create --permission-ids 148,142,38 --role qa-user 
# view_environments,create_environments,edit_environments,destroy_environments,import_environments
hammer filter create --permission-ids 43,44,45,46,47 --role qa-user 
# edit_classes
hammer filter create --permission-ids 66 --role qa-user 
# view_hostgroups, edit_hostgroups
hammer filter create --permission-ids 70,72 --role qa-user 
# view_hosts, create_hosts, edit_hosts, destroy_hosts, build_hosts, power_hosts, console_hosts, ipmi_boot, puppetrun_hosts
hammer filter create --permission-ids 74,75,76,77,78,79,80,82 --role qa-user 
# view_locations
hammer filter create --permission-ids 87 --role qa-user 
# view_organizations
hammer filter create --permission-ids 105 --role qa-user 
# view_puppetclasses
hammer filter create --permission-ids 115 --role qa-user 
# view_smart_proxies, view_smart_proxies_autosign, view_smart_proxies_puppetca
hammer filter create --permission-ids 132,136,139 --role qa-user 

# my_organizations
hammer filter create --permission-ids 223 --role qa-user
# view_products
hammer filter create --permission-ids 209 --role qa-user
# edit_classes
hammer filter create --permission-ids 66 --role qa-user
# view_lifecycle_environments,edit_lifecycle_environments
hammer filter create --permission-ids 204,206 --role qa-user
# FILTERED: view_content_views,create_content_views,edit_content_views,publish_content_views,promote_or_remove_content_views
hammer filter create --permission-ids 190,191,192,194,195 --search 'name ~ ccv*' --role qa-user 
# FILTERED: promote_or_remove_content_views_to_environments
hammer filter create --permission-ids 208 --search 'name ~ QA' --role qa-user


# new permissions of GA SNAP7+
# 
# hammer filter available-permissions --per-page 500
#----|-------------------------------------------------|------------------------
#ID  | NAME                                            | RESOURCE               
#----|-------------------------------------------------|------------------------
#1   | view_architectures                              | Architecture           
#2   | create_architectures                            | Architecture           
#3   | edit_architectures                              | Architecture           
#4   | destroy_architectures                           | Architecture           
#5   | view_audit_logs                                 | Audit                  
#6   | view_authenticators                             | AuthSourceLdap         
#7   | create_authenticators                           | AuthSourceLdap         
#8   | edit_authenticators                             | AuthSourceLdap         
#9   | destroy_authenticators                          | AuthSourceLdap         
#10  | view_bookmarks                                  | Bookmark               
#11  | create_bookmarks                                | Bookmark               
#12  | edit_bookmarks                                  | Bookmark               
#13  | destroy_bookmarks                               | Bookmark               
#14  | view_compute_profiles                           | ComputeProfile         
#15  | create_compute_profiles                         | ComputeProfile         
#16  | edit_compute_profiles                           | ComputeProfile         
#17  | destroy_compute_profiles                        | ComputeProfile         
#18  | view_compute_resources                          | ComputeResource        
#19  | create_compute_resources                        | ComputeResource        
#20  | edit_compute_resources                          | ComputeResource        
#21  | destroy_compute_resources                       | ComputeResource        
#22  | view_compute_resources_vms                      | ComputeResource        
#23  | create_compute_resources_vms                    | ComputeResource        
#24  | edit_compute_resources_vms                      | ComputeResource        
#25  | destroy_compute_resources_vms                   | ComputeResource        
#26  | power_compute_resources_vms                     | ComputeResource        
#27  | console_compute_resources_vms                   | ComputeResource        
#28  | view_templates                                  | ConfigTemplate         
#29  | create_templates                                | ConfigTemplate         
#30  | edit_templates                                  | ConfigTemplate         
#31  | destroy_templates                               | ConfigTemplate         
#32  | deploy_templates                                | ConfigTemplate         
#33  | lock_templates                                  | ConfigTemplate         
#34  | view_config_groups                              | ConfigGroup            
#35  | create_config_groups                            | ConfigGroup            
#36  | edit_config_groups                              | ConfigGroup            
#37  | destroy_config_groups                           | ConfigGroup            
#38  | access_dashboard                                | (Miscellaneous)        
#39  | view_domains                                    | Domain                 
#40  | create_domains                                  | Domain                 
#41  | edit_domains                                    | Domain                 
#42  | destroy_domains                                 | Domain                 
#43  | view_environments                               | Environment            
#44  | create_environments                             | Environment            
#45  | edit_environments                               | Environment            
#46  | destroy_environments                            | Environment            
#47  | import_environments                             | Environment            
#48  | view_external_usergroups                        | ExternalUsergroups     
#49  | create_external_usergroups                      | ExternalUsergroups     
#50  | edit_external_usergroups                        | ExternalUsergroups     
#51  | destroy_external_usergroups                     | ExternalUsergroups     
#52  | view_external_variables                         | LookupKey              
#53  | create_external_variables                       | LookupKey              
#54  | edit_external_variables                         | LookupKey              
#55  | destroy_external_variables                      | LookupKey              
#56  | view_facts                                      | FactValue              
#57  | upload_facts                                    | FactValue              
#58  | view_filters                                    | Filter                 
#59  | create_filters                                  | Filter                 
#60  | edit_filters                                    | Filter                 
#61  | destroy_filters                                 | Filter                 
#62  | view_globals                                    | CommonParameter        
#63  | create_globals                                  | CommonParameter        
#64  | edit_globals                                    | CommonParameter        
#65  | destroy_globals                                 | CommonParameter        
#66  | edit_classes                                    | HostClass              
#67  | create_params                                   | Parameter              
#68  | edit_params                                     | Parameter              
#69  | destroy_params                                  | Parameter              
#70  | view_hostgroups                                 | Hostgroup              
#71  | create_hostgroups                               | Hostgroup              
#72  | edit_hostgroups                                 | Hostgroup              
#73  | destroy_hostgroups                              | Hostgroup              
#74  | view_hosts                                      | Host                   
#75  | create_hosts                                    | Host                   
#76  | edit_hosts                                      | Host                   
#77  | destroy_hosts                                   | Host                   
#78  | build_hosts                                     | Host                   
#79  | power_hosts                                     | Host                   
#80  | console_hosts                                   | Host                   
#81  | ipmi_boot                                       | Host                   
#82  | puppetrun_hosts                                 | Host                   
#83  | view_images                                     | Image                  
#84  | create_images                                   | Image                  
#85  | edit_images                                     | Image                  
#86  | destroy_images                                  | Image                  
#87  | view_locations                                  | Location               
#88  | create_locations                                | Location               
#89  | edit_locations                                  | Location               
#90  | destroy_locations                               | Location               
#91  | assign_locations                                | Location               
#92  | view_mail_notifications                         | MailNotification       
#93  | view_media                                      | Medium                 
#94  | create_media                                    | Medium                 
#95  | edit_media                                      | Medium                 
#96  | destroy_media                                   | Medium                 
#97  | view_models                                     | Model                  
#98  | create_models                                   | Model                  
#99  | edit_models                                     | Model                  
#100 | destroy_models                                  | Model                  
#101 | view_operatingsystems                           | Operatingsystem        
#102 | create_operatingsystems                         | Operatingsystem        
#103 | edit_operatingsystems                           | Operatingsystem        
#104 | destroy_operatingsystems                        | Operatingsystem        
#105 | view_organizations                              | Organization           
#106 | create_organizations                            | Organization           
#107 | edit_organizations                              | Organization           
#108 | destroy_organizations                           | Organization           
#109 | assign_organizations                            | Organization           
#110 | view_ptables                                    | Ptable                 
#111 | create_ptables                                  | Ptable                 
#112 | edit_ptables                                    | Ptable                 
#113 | destroy_ptables                                 | Ptable                 
#114 | view_plugins                                    | (Miscellaneous)        
#115 | view_puppetclasses                              | Puppetclass            
#116 | create_puppetclasses                            | Puppetclass            
#117 | edit_puppetclasses                              | Puppetclass            
#118 | destroy_puppetclasses                           | Puppetclass            
#119 | import_puppetclasses                            | Puppetclass            
#120 | view_realms                                     | Realm                  
#121 | create_realms                                   | Realm                  
#122 | edit_realms                                     | Realm                  
#123 | destroy_realms                                  | Realm                  
#124 | view_reports                                    | Report                 
#125 | destroy_reports                                 | Report                 
#126 | upload_reports                                  | Report                 
#127 | view_roles                                      | Role                   
#128 | create_roles                                    | Role                   
#129 | edit_roles                                      | Role                   
#130 | destroy_roles                                   | Role                   
#131 | access_settings                                 | (Miscellaneous)        
#132 | view_smart_proxies                              | SmartProxy             
#133 | create_smart_proxies                            | SmartProxy             
#134 | edit_smart_proxies                              | SmartProxy             
#135 | destroy_smart_proxies                           | SmartProxy             
#136 | view_smart_proxies_autosign                     | SmartProxy             
#137 | create_smart_proxies_autosign                   | SmartProxy             
#138 | destroy_smart_proxies_autosign                  | SmartProxy             
#139 | view_smart_proxies_puppetca                     | SmartProxy             
#140 | edit_smart_proxies_puppetca                     | SmartProxy             
#141 | destroy_smart_proxies_puppetca                  | SmartProxy             
#142 | view_statistics                                 | (Miscellaneous)        
#143 | view_subnets                                    | Subnet                 
#144 | create_subnets                                  | Subnet                 
#145 | edit_subnets                                    | Subnet                 
#146 | destroy_subnets                                 | Subnet                 
#147 | import_subnets                                  | Subnet                 
#148 | view_tasks                                      | (Miscellaneous)        
#149 | view_trends                                     | Trend                  
#150 | create_trends                                   | Trend                  
#151 | edit_trends                                     | Trend                  
#152 | destroy_trends                                  | Trend                  
#153 | update_trends                                   | Trend                  
#154 | view_usergroups                                 | Usergroup              
#155 | create_usergroups                               | Usergroup              
#156 | edit_usergroups                                 | Usergroup              
#157 | destroy_usergroups                              | Usergroup              
#158 | view_users                                      | User                   
#159 | create_users                                    | User                   
#160 | edit_users                                      | User                   
#161 | destroy_users                                   | User                   
#162 | view_containers                                 | Container              
#163 | commit_containers                               | Container              
#164 | create_containers                               | Container              
#165 | destroy_containers                              | Container              
#166 | view_registries                                 | DockerRegistry         
#167 | create_registries                               | DockerRegistry         
#168 | destroy_registries                              | DockerRegistry         
#169 | search_repository_image_search                  | Docker/ImageSearch     
#170 | view_discovered_hosts                           | Host                   
#171 | provision_discovered_hosts                      | Host                   
#172 | edit_discovered_hosts                           | Host                   
#173 | destroy_discovered_hosts                        | Host                   
#174 | view_discovery_rules                            | DiscoveryRule          
#175 | new_discovery_rules                             | DiscoveryRule          
#176 | edit_discovery_rules                            | DiscoveryRule          
#177 | execute_discovery_rules                         | DiscoveryRule          
#178 | delete_discovery_rules                          | DiscoveryRule          
#179 | view_foreman_tasks                              | ForemanTasks::Task     
#180 | edit_foreman_tasks                              | ForemanTasks::Task     
#181 | view_activation_keys                            | Katello::ActivationKey 
#182 | create_activation_keys                          | Katello::ActivationKey 
#183 | edit_activation_keys                            | Katello::ActivationKey 
#184 | destroy_activation_keys                         | Katello::ActivationKey 
#185 | manage_capsule_content                          | SmartProxy             
#186 | view_content_hosts                              | Katello::System        
#187 | create_content_hosts                            | Katello::System        
#188 | edit_content_hosts                              | Katello::System        
#189 | destroy_content_hosts                           | Katello::System        
#190 | view_content_views                              | Katello::ContentView   
#191 | create_content_views                            | Katello::ContentView   
#192 | edit_content_views                              | Katello::ContentView   
#193 | destroy_content_views                           | Katello::ContentView   
#194 | publish_content_views                           | Katello::ContentView   
#195 | promote_or_remove_content_views                 | Katello::ContentView   
#196 | view_gpg_keys                                   | Katello::GpgKey        
#197 | create_gpg_keys                                 | Katello::GpgKey        
#198 | edit_gpg_keys                                   | Katello::GpgKey        
#199 | destroy_gpg_keys                                | Katello::GpgKey        
#200 | view_host_collections                           | Katello::HostCollection
#201 | create_host_collections                         | Katello::HostCollection
#202 | edit_host_collections                           | Katello::HostCollection
#203 | destroy_host_collections                        | Katello::HostCollection
#204 | view_lifecycle_environments                     | Katello::KTEnvironment 
#205 | create_lifecycle_environments                   | Katello::KTEnvironment 
#206 | edit_lifecycle_environments                     | Katello::KTEnvironment 
#207 | destroy_lifecycle_environments                  | Katello::KTEnvironment 
#208 | promote_or_remove_content_views_to_environments | Katello::KTEnvironment 
#209 | view_products                                   | Katello::Product       
#210 | create_products                                 | Katello::Product       
#211 | edit_products                                   | Katello::Product       
#212 | destroy_products                                | Katello::Product       
#213 | sync_products                                   | Katello::Product       
#214 | view_subscriptions                              | Organization           
#215 | attach_subscriptions                            | Organization           
#216 | unattach_subscriptions                          | Organization           
#217 | import_manifest                                 | Organization           
#218 | delete_manifest                                 | Organization           
#219 | view_sync_plans                                 | Katello::SyncPlan      
#220 | create_sync_plans                               | Katello::SyncPlan      
#221 | edit_sync_plans                                 | Katello::SyncPlan      
#222 | destroy_sync_plans                              | Katello::SyncPlan      
#223 | my_organizations                                | (Miscellaneous)        
#224 | view_search                                     | (Miscellaneous)        
#225 | view_cases                                      | (Miscellaneous)        
#226 | attachments                                     | (Miscellaneous)        
#227 | configuration                                   | (Miscellaneous)        
#228 | app_root                                        | (Miscellaneous)        
#229 | view_log_viewer                                 | (Miscellaneous)        
#230 | logs                                            | (Miscellaneous)        
#231 | rh_telemetry_api                                | (Miscellaneous)        
#232 | rh_telemetry_view                               | (Miscellaneous)        
#233 | rh_telemetry_configurations                     | (Miscellaneous)        
#234 | download_bootdisk                               | (Miscellaneous)        
#----|-------------------------------------------------|------------------------

