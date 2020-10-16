#!/bin/bash

env

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json
wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-prod.json

case $NAMESPACE in

  *"dev"*)
    echo -n "Using non-prod deployment json"
    cp deploy-ace.json deploy.json
    ;;

  *"sit"*)
    echo -n "Using non-prod deployment json"
    cp deploy-ace.json deploy.json
    ;;

  *"uat"*)
    echo -n "Using non-prod deployment json"
    cp deploy-ace.json deploy.json
    ;;

  *"pt"*)
    echo -n "Using prod deployment json"
    cp deploy-ace-prod.json deploy.json
    ;;

  *"prod"*)
    echo -n "Using prod deployment json"
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

echo "DRY RUN..."
cat deploy5.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - --dry-run -o yaml

echo "DEPLOYING..."
cat deploy5.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - 
