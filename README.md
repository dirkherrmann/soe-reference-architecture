# soe-reference-architecture
This github repo contains all files and scripts which have been used while writing the SOE reference architecture

Basically the setup lifecycle could be divided into 3 steps where each of them has its own script:

1. Prepare the Setup (long-running tasks): soe-prep-setup.sh
2. Execute the Setup (the core of the setup): soe-setup.sh
3. Clean-Up the Setup (delete all items which have been setup): soe-cleanup

Step 1: Prepare the Setup

The first script you have to run is the soe-prep-setup.sh script. It initially configures 

* your Satellite 6 demo organization
* your Red Hat subscription manifest (you need to have it before)
* the Red Hat Enterprise Linux software repositories we need
* the 3rd repositories we need

It usally runs a couple of hours, depending on your internet connection. 

Step 2: Exectute the Setup


Step 3 (optional): clean-up everything

