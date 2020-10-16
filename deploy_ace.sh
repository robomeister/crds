#!/bin/bash

env

if [[ -z ${NAMESPACE} ]];
then
   echo "Please set the NAMESPACE environment variable"
   exit 1
fi

if [[ -z ${REPLICAS} ]];
then
   REPLICAS=1
fi

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json
wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-prod.json

echo "Using default non-prod deployment json"
cp deploy-ace.json deploy.json

case $NAMESPACE in
  *"pt"*|*"prod"*|*"dr"*)
    echo "Switching to production deployment json"
    cp deploy-ace-prod.json deploy.json
    ;;
esac

cat deploy.json

if [[ -z ${SERVER_CONF} ]];
then
      cp  deploy.json deploy1.json
else
      cat deploy.json | jq '.spec.configurations += ["'${SERVER_CONF}'"]' > deploy1.json
fi

if [[ -z ${MAX_CPU} ]];
then
      cp  deploy1.json deploy2.json
else
      cat deploy1.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${MAX_CPU}'"' > deploy2.json
fi

if [[ -z ${MAX_MEMORY} ]];
then
      cp  deploy2.json deploy3.json
else
      cat deploy2.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${MAX_MEMORY}'"' > deploy3.json
fi

if [[ -z ${MIN_CPU} ]];
then
      cp  deploy3.json deploy4.json
else
      cat deploy3.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${MIN_CPU}'"' > deploy4.json
fi

if [[ -z ${MIN_MEMORY} ]];
then
      cp  deploy4.json deploy5.json
else
      cat deploy4.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${MIN_MEMORY}'"' > deploy5.json
fi


cat deploy5.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'" | .metadata.namespace = "'${NAMESPACE}'" | .spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deployment.json

echo "DRY RUN..."
oc apply -f deployment.json --dry-run -o yaml

echo "DEPLOYING..."
oc apply -f deployment.json

sleep 10s

DEPLOYMENT_NAME=${NAMESPACE}-${IDS_PROJECT_NAME}-is

set -x
if oc rollout status deploy/${DEPLOYMENT_NAME} --watch=true --request-timeout="300s" --namespace ${NAMESPACE}; then
  STATUS="pass"
else
  STATUS="fail"
fi
set +x

if [ "$STATUS" == "fail" ]; then
  echo "DEPLOYMENT FAILED"
  exit 1
fi
