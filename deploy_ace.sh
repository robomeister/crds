#!/bin/bash

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json

cat deploy-ace.json

echo "DRY RUN..."
cat deploy-ace.json |  jq '.metadata.name = "'${IDS_PROJECT_NAME}'-'${NAMESPACE}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - --dry-run -o yaml

echo "DEPLOYING..."
cat deploy-ace.json |  jq '.metadata.name = "'${IDS_PROJECT_NAME}'-'${NAMESPACE}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - 

echo "Sleeping for a few seconds"
sleep 3

echo "deleting routes"
oc -n ${NAMESPACE}  delete route ${IDS_PROJECT_NAME}-${NAMESPACE}-http
oc -n ${NAMESPACE}  delete route ${IDS_PROJECT_NAME}-${NAMESPACE}-https
