#!/bin/bash

env

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json

cat deploy-ace.json



if [[ -z ${SERVERCONF} ]];
then
      cp deploy-ace.json deploy-conf.json
else
      echo "Adding server configuration ${SERVERCONF}"
      cat deploy-ace.json | jq '.spec.configurations += ["'${SERVERCONF}'"]' > deploy-conf.json
fi

echo "SERVERCONF"
cat deploy-conf.json

echo "DRY RUN..."
cat deploy-conf.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - --dry-run -o yaml

echo "DEPLOYING..."
cat deploy-conf.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - 
