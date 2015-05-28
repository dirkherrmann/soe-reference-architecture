DIR="$PWD"
source "${DIR}/common.sh"

TMPIFS=$IFS
IFS=","
# create location
for LOC in ${LOCATIONS}
do
  hammer location create --name "${LOC}"
  hammer location add-organization --name "${LOC}" --organization "${ORG}"
done
IFS=$TMPIFS
