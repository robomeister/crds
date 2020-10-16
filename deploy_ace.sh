#!/bin/bash

env

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json

cat deploy-ace.json

if [[ -z ${SERVER_CONF} ]];
then
      cp  deploy-ace.json deploy-conf.json
else
      cat deploy-ace.json | jq '.spec.configurations += ["'${SERVER_CONF}'"]' > deploy-conf.json
fi

if [[ -z ${MAX_CPU} ]];
then
      cp  deploy-conf.json deploy-max-cpu.json
else
      cat deploy-conf.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${MAX_CPU}'"' > deploy-max-cpu.json
fi

if [[ -z ${MAX_MEMORY} ]];
then
      cp  deploy-max-cpu.json deploy-max-mem.json
else
      cat deploy-max-cpu.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${MAX_MEMORY}'"' > deploy-max-mem.json
fi

if [[ -z ${MIN_CPU} ]];
then
      cp  deploy-max-mem.json deploy-min-cpu.json
else
      cat deploy-max-mem.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${MIN_CPU}'"' > deploy-min-cpu.json
fi

if [[ -z ${MIN_MEMORY} ]];
then
      cp  deploy-min-cpu.json deploy-min-mem.json
else
      cat deploy-min-cpu.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${MIN_MEMORY}'"' > deploy-min-mem.json
fi

echo "DRY RUN..."
cat deploy-min-mem.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - --dry-run -o yaml

echo "DEPLOYING..."
cat deploy-min-mem.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - 
