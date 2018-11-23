#!/usr/bin/env bash


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
  "use_existing_org": true,
  "use_existing_space": true
}
EOF

cat $CONFIG

loggregator_enabled=${loggregator_enabled:0}
if [[ "${loggregator_enabled}" == 0 ]]
then
  loggregator="--skip=Loggregator"
else
  loggregator="--focus=Loggregator:"
fi


cd /go/src/github.com/cloudfoundry/cf-smoke-tests/
ginkgo -r --succinct -slowSpecThreshold=300 -v -trace ${loggregator}

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
          \"tags\":[\"deployment:$deployment\",\"loggregator_enabled:$loggregator_enabled\"]"

curl -X POST -H "Content-type: application/json" \
  -d "{ \"series\" :
         [{\"metric\":\"smoke.status\",
          \"points\":[[$currenttime, $cf_smoke_success]],
          \"type\":\"gauge\",
          \"tags\":[\"deployment:$deployment\",\"loggregator_enabled:$loggregator_enabled\"]
        }]
      }" \
"https://app.datadoghq.com/api/v1/series?api_key=${datadog_key}"


ELAPSED_TIME=`expr $currenttime - $starttime`

echo "execution time curl data: \"series\" :
         [{\"metric\":\"smoke.execution_time_ms\",
          \"points\":[[$currenttime, $ELAPSED_TIME]],
          \"type\":\"gauge\",
          \"tags\":[\"deployment:$deployment\",\"loggregator_enabled:$loggregator_enabled\"]"


curl -X POST -H "Content-type: application/json" \
  -d "{ \"series\" :
         [{\"metric\":\"smoke.execution_time_ms\",
          \"points\":[[$currenttime, $ELAPSED_TIME]],
          \"type\":\"gauge\",
          \"tags\":[\"deployment:$deployment\",\"loggregator_enabled:$loggregator_enabled\"]
        }]
      }" \
"https://app.datadoghq.com/api/v1/series?api_key=${datadog_key}"

if [[ $? -ne 0 ]]; then
  echo "curl failed with exit status $?"
  exit 1
fi

exit $EXITSTATUS
