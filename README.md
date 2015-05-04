# soe-reference-architecture
This github repo contains all files and scripts which have been used while writing the SOE reference architecture

Pre-Requisites

* Satellite 6.1+ server installed and up and running
* Satellite 6 admin user created (credentials user/pass)
* existing Red Hat subscription manifest downloaded from Red Hat Customer Portal (see CFG file for path)
* hammer CLI installed locally
* local checkout of this repository: git clone https://github.com/dirkherrmann/soe-reference-architecture
* change directory to git checkkout: cd ./soe-reference-architecture
 
The reference architecture is divide into 10 steps. For each step there is a dedicated script called stepX.sh while X is the step number. The idea is that the reader of the reference architecture executes each script after reading the chapter.

For other use cases we don't need to separate the execution into 2 steps. Basically the setup lifecycle could be divided into 3 steps where each of them has its own script:

1. Prepare the Setup (long-running tasks): soe-prep-setup.sh (executes primarily step1.sh)
2. Execute the Setup (the core of the setup): soe-setup.sh (executes step 2-10)
3. Clean-Up the Setup (delete all items which have been setup): soe-cleanup

Step 1: Prepare the Setup

The first script you have to run is the soe-prep-setup.sh script. It initially configures 

* your Satellite 6 demo organization
* your Red Hat subscription (you need to have the manifest before)
* the Red Hat Enterprise Linux software repositories we need
* the 3rd repositories we need

It usally runs a couple of hours, depending on your internet connection and current CDN performance. 

Step 2: Exectute the Setup


Step 3 (optional): clean-up everything

