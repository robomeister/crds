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

rm deploy-ace.json
rm deploy-ace-prod.json

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-sap.json
wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-sap-prod.json

case $NAMESPACE in
  *"pt"*|*"prod"*|*"dr"*)
    echo "Using PRODUCTION deployment json"
    cp deploy-ace-sap-prod.json deploy.json
    ;;
  *)
    echo "Using non-prod deployment json"
    cp deploy-ace-sap.json deploy.json
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

if [[ -z ${WORKER_NODE} ]];
then
      cp  deploy5.json deploy6.json
else
      cat deploy5.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${WORKER_NODE}'"]}]' > deploy6.json
fi

cat deploy6.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'" | .metadata.namespace = "'${NAMESPACE}'" | .spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deploy6.json

if [[ -z ${POLICY_CONF} ]];
then
      cp  deploy6.json deploy7.json
else
      cat deploy6.json | jq '.spec.configurations += ["'${POLICY_CONF}'"]' > deploy7.json
fi

if [[ -z ${DBPARMS_CONF} ]];
then
      cp  deploy7.json deploy8.json
else
      cat deploy7.json | jq '.spec.configurations += ["'${DBPARMS_CONF}'"]' > deploy8.json
fi


echo "DRY RUN..."
oc apply -f deploy8.json --dry-run -o yaml

echo "DEPLOYING..."
oc apply -f deploy8.json

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
else
   if [[ -z ${MATCH_SELECTOR} ]];
   then
      echo "No Match Selector Specified"
   else
      echo "Re-applying the deployment..."
      oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json | jq '.spec.selector.matchLabels.'${MATCH_SELECTOR}'="true" | .metadata.labels.'${MATCH_SELECTOR}'="true" | .spec.template.metadata.labels.'${MATCH_SELECTOR}'="true"' | oc -n ${NAMESPACE} replace --force -f -
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
   fi
fi
