#!/bin/bash

set -eu

TEMP_DEPLOYED_PRODUCTS=$(mktemp)
TEMP_STAGED_PRODUCTS=$(mktemp)
DEPLOYED_MANIFEST=$(mktemp)
STAGED_MANIFEST=$(mktemp)
OM_CMD="om --env env/${ENV_FILE} -k curl --silent --path"

#get jq installed
apt-get install -y jq

# Get all the deployed products
${OM_CMD} /api/v0/deployed/products | jq -r .[].guid | grep -v bosh > ${TEMP_DEPLOYED_PRODUCTS}
${OM_CMD} /api/v0/staged/products | jq -r .[].guid > ${TEMP_STAGED_PRODUCTS}

while read i; do
    if grep -q ${i} ${TEMP_DEPLOYED_PRODUCTS}
    then
        echo "****** $i STAGED CHANGES ******"
        # Get the deployed manifest given a product guid
        ${OM_CMD} /api/v0/deployed/products/${i}/manifest > ${DEPLOYED_MANIFEST}
        sleep 1

        #Get the staged manifest
        ${OM_CMD} /api/v0/staged/products/${i}/manifest | jq .manifest > ${STAGED_MANIFEST}
        sleep 1

        # Diff the files
        diff --unified=5 ${DEPLOYED_MANIFEST} ${STAGED_MANIFEST} || true
    fi
done < ${TEMP_STAGED_PRODUCTS}
