containerhost=$2
HG=$(hammer --output csv host list | awk -F "," "/$containerhost/ {print \$4}")
if [ -n $HG ] 
then 
  if [[ $HG =~ "containerhost" ]]
  then
    sleep 720
    ORG="ACME"
    LOC="munich-dmz"
    hammer compute-resource create \
    --name "${containerhost}" \
    --description "containerhost ${containerhost}" \
    --url "https://${containerhost}:4243" \
    --provider "docker" \
    --organizations "${ORG}" \
    --locations "${LOC}"
  fi
fi
