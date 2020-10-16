#!/bin/bash

env

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json

cat deploy-ace.json



if [[ -z ${SERVER_CONF} ]];
then
      cp deploy-ace.json deploy-conf.json
else
      echo "Adding server configuration ${SERVER_CONF}"
      cat deploy-ace.json | jq '.spec.configurations += ["'${SERVER_CONF}'"]' > deploy-conf.json
fi

echo "SERVERCONF"
cat deploy-conf.json

if [[ -z ${MAX_CPU} ]];
then
      cp deploy-conf.json deploy-cpu.json
else
      cat deploy-conf.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="${MAX_CPU}"' > deploy-cpu.json
fi

echo "CPU"
cat deploy-cpu.json

if [[ -z ${MAX_MEMORY} ]];
then
      cp deploy-cpu.json deploy-mem.json
else
      cat deploy-cpu.json | jq '.spec.pod.containers.runtime.resources.limits.memory="${MAX_MEMORY}"' > deploy-mem.json
fi

echo "MEMORY"
cat deploy-mem.json

echo "DRY RUN..."
cat deploy-mem.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - --dry-run -o yaml

echo "DEPLOYING..."
cat deploy-mem.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - 
