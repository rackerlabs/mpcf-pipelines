#!/bin/bash 

set -eu

TEMP_DEPLOYED_PRODUCTS=$(mktemp)
TEMP_STAGED_PRODUCTS=$(mktemp)
DEPLOYED_MANIFEST=$(mktemp)
STAGED_MANIFEST=$(mktemp)

alias om="om --env env/${ENV_FILE}"

#get jq installed
apt-get install -y jq

# Get all the deployed products
om -k curl --silent  --path /api/v0/deployed/products | jq -r .[].guid | grep -v bosh > ${TEMP_DEPLOYED_PRODUCTS}
om -k curl --silent  --path /api/v0/staged/products | jq -r .[].guid > ${TEMP_STAGED_PRODUCTS}


while read i; do
    if grep -q ${i} ${TEMP_DEPLOYED_PRODUCTS}
    then
	echo "****** $i STAGED CHANGES ******"
	# Get the deployed manifest given a product guid
	om -k curl --path /api/v0/deployed/products/${i}/manifest --silent > ${DEPLOYED_MANIFEST}

	#Get the staged manifest
	om -k curl --path /api/v0/staged/products/${i}/manifest --silent | jq .manifest > ${STAGED_MANIFEST}

	# Diff the files
	diff --unified=5 ${DEPLOYED_MANIFEST} ${STAGED_MANIFEST} || true
    fi
done < ${TEMP_STAGED_PRODUCTS}
