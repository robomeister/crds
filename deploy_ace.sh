#!/bin/bash

env

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json

cat deploy-ace.json



if [[ -z ${SERVERCONF} ]];
then
      echo "\$SERVERCONF is not set"
else
      echo "TEST"
      cat deploy-ace.json | jq '.spec.configurations += ["'${SERVERCONF}'"]' > new-deploy.json
      echo "DONE TEST"
fi

cat new-deploy.json

echo "DRY RUN..."
cat deploy-ace.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - --dry-run -o yaml

echo "DEPLOYING..."
cat deploy-ace.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.replicas='${REPLICAS}'' | oc apply -f - 

#echo "Sleeping for several seconds"
#sleep 15

#echo "deleting routes"
#echo "oc -n ${NAMESPACE}  delete route ${IDS_PROJECT_NAME}-${NAMESPACE}-http"
#oc -n ${NAMESPACE}  delete route ${IDS_PROJECT_NAME}-${NAMESPACE}-http

#echo "-n ${NAMESPACE}  delete route ${IDS_PROJECT_NAME}-${NAMESPACE}-https"
#oc -n ${NAMESPACE}  delete route ${IDS_PROJECT_NAME}-${NAMESPACE}-https
