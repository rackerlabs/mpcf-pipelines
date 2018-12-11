#!/usr/bin/env bash
set -u

starttime=$(date +%s)

EXITSTATUS=0

export CONFIG=$(pwd)/runtime-smoke-config.json

tee $CONFIG <<EOF
{
  "suite_name": "RUNTIME-SMOKE",
  "api": "${cf_api}",
  "apps_domain": "${cf_apps_domain}",
  "skip_ssl_validation": true,
  "user": "${cf_user}",
  "password": "${cf_password}",
  "org": "${cf_org}",
  "space": "${cf_space}",
  "deployment": "${cf_deployment}",
  "use_existing_org": true,
  "use_existing_space": true
}
EOF

cat $CONFIG

wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
mv jq-linux64 jq
chmod +x ./jq

cf login -a "${cf_api}" -u "${cf_user}" -p "${cf_password}" -o "${cf_org}" -s "${cf_space}"

# If there are other apps in the cf org and space, let's just fail
space_guid=$(cf curl /v2/spaces | ./jq -r --arg i "${cf_space}" '.resources[] | select(.entity.name == $i) | .metadata.guid')
if [ -z "$space_guid" ]
then
   echo "unable to determine space guid."
   exit 1
fi

space_apps=$(cf curl /v2/spaces/"${space_guid}"/apps | ./jq .total_results)

if [[ $space_apps != "0" ]]
then
    echo "number of apps in this space does not equal 0. refusing to run"
    exit 1
fi

cd /go/src/github.com/cloudfoundry/cf-smoke-tests/
ginkgo -r --succinct -slowSpecThreshold=300 -v -trace

EXITSTATUS=$?
# halp
[[ $EXITSTATUS -eq 0 ]] && cf_smoke_success=1 || cf_smoke_success=0

echo "ginkgo exit status: $EXITSTATUS"
echo "cf smoke success value to be sent to datadog: $cf_smoke_success"

if [[ "$datadog_key" == "DEBUG_SKIP" ]]
then
  echo "Skipping Datadog step [DEBUG_SKIP]"
  exit $EXITSTATUS
fi
currenttime=$(date +%s)


echo "smoke.status curl data: \"series\" :
         [{\"metric\":\"smoke.status\",
          \"points\":[[$currenttime, $cf_smoke_success]],
          \"type\":\"gauge\",
          \"tags\":[\"deployment:$cf_deployment\"]"

curl -X POST -H "Content-type: application/json" \
  -d "{ \"series\" :
         [{\"metric\":\"smoke.status\",
          \"points\":[[$currenttime, $cf_smoke_success]],
          \"type\":\"gauge\",
          \"tags\":[\"deployment:$cf_deployment\"]
        }]
      }" \
"https://app.datadoghq.com/api/v1/series?api_key=${datadog_key}"


ELAPSED_TIME=`expr $currenttime - $starttime`

echo "execution time curl data: \"series\" :
         [{\"metric\":\"smoke.execution_time_ms\",
          \"points\":[[$currenttime, $ELAPSED_TIME]],
          \"type\":\"gauge\",
          \"tags\":[\"deployment:$cf_deployment\"]"


curl -X POST -H "Content-type: application/json" \
  -d "{ \"series\" :
         [{\"metric\":\"smoke.execution_time_ms\",
          \"points\":[[$currenttime, $ELAPSED_TIME]],
          \"type\":\"gauge\",
          \"tags\":[\"deployment:$cf_deployment\"]
        }]
      }" \
"https://app.datadoghq.com/api/v1/series?api_key=${datadog_key}"

if [[ $? -ne 0 ]]; then
  echo "curl failed with exit status $?"
  exit 1
fi

exit $EXITSTATUS
