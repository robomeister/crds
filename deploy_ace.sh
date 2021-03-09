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

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json

cp deploy-ace.json deploy.json

echo "Default json"
cat deploy.json

case $NAMESPACE in
  *"pt"*|*"prod"*|*"dr"*)
    echo "Setting PRODUCTION default memory and cpu"
	DEFAULT_MIN_CPU="1000m"
	DEFAULT_MAX_CPU="4000m"
    DEFAULT_MIN_MEMORY="1024Mi"
	DEFAULT_MAX_MEMORY="4096Mi"
    ;;
  *)
    echo "Setting NON-PRODUCTION default memory and cpu"
	DEFAULT_MIN_CPU="125m"
	DEFAULT_MAX_CPU="250m"
    DEFAULT_MIN_MEMORY="256Mi"
	DEFAULT_MAX_MEMORY="512Mi"
    ;;    
esac


if [[ -z ${SERVER_CONF} ]];
then
      cp  deploy.json deploy1.json
else
      cat deploy.json | jq '.spec.configurations += ["'${SERVER_CONF}'"]' > deploy1.json
fi

if [[ -z ${MAX_CPU} ]];
then
      cat deploy1.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${DEFAULT_MAX_CPU}'"' > deploy2.json
else
      cat deploy1.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${MAX_CPU}'"' > deploy2.json
fi

if [[ -z ${MAX_MEMORY} ]];
then
      cat deploy2.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${DEFAULT_MAX_MEMORY}'"' > deploy3.json
else
      cat deploy2.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${MAX_MEMORY}'"' > deploy3.json
fi

if [[ -z ${MIN_CPU} ]];
then
      cat deploy3.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${DEFAULT_MIN_CPU}'"' > deploy4.json
else
      cat deploy3.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${MIN_CPU}'"' > deploy4.json
fi

if [[ -z ${MIN_MEMORY} ]];
then
      cat deploy4.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${DEFAULT_MIN_MEMORY}'"' > deploy5.json
else
      cat deploy4.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${MIN_MEMORY}'"' > deploy5.json
fi

if [[ -z ${WORKER_NODE} ]];
then
      cp  deploy5.json deploy6.json
else
      cat deploy5.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${WORKER_NODE}'"]}]' > deploy6.json
fi

if [[ -z ${NO_CONFIGS} ]];
then
      cp  deploy6.json deploy7.json
else
      cat deploy6.json | jq 'del (.spec.configurations)' > deploy7.json
fi

cat deploy7.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'" | .metadata.namespace = "'${NAMESPACE}'" | .spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deployment.json

echo "editted json"
cat deployment.json  

echo "DRY RUN..."
oc apply -f deployment.json --dry-run -o yaml

echo "DEPLOYING..."
oc apply -f deployment.json

sleep 10s

DEPLOYMENT_NAME=${NAMESPACE}-${IDS_PROJECT_NAME}-is

set -x
if oc rollout status deploy/${DEPLOYMENT_NAME} --watch=true --request-timeout="1200s" --namespace ${NAMESPACE}; then
  STATUS="pass"
else
  STATUS="fail"
fi
set +x

if [ "$STATUS" == "fail" ]; then
  echo "DEPLOYMENT FAILED"
  exit 1
else
   oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json

   if [[ -z ${MATCH_SELECTOR} ]];
   then
      echo "No Match Selector Specified.  Enabling metrics and setting log4j PVC..."
	  cat deployed.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deployed-1.json
      cat deployed-1.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-adj-splunk-uf"} }]' >deployed-2.json
      cat deployed-2.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deployed-3.json

#oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json | jq '.spec.template.spec.containers[0].env[1].value="true"' | oc -n ${NAMESPACE} replace --force -f -
   else
      echo "Updating Match Selectors and enabling metrics and setting log4j PVC..."
      cat deployed.json  | jq '.spec.template.spec.containers[0].env[1].value="true" | .spec.selector.matchLabels.'${MATCH_SELECTOR}'="true" | .metadata.labels.'${MATCH_SELECTOR}'="true" | .spec.template.metadata.labels.'${MATCH_SELECTOR}'="true"' >deployed-0.json
	  cat deployed-0.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deployed-1.json
      cat deployed-1.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-adj-splunk-uf"} }]' >deployed-2.json
      cat deployed-2.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deployed-3.json

#oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json | jq '.spec.template.spec.containers[0].env[1].value="true" | .spec.selector.matchLabels.'${MATCH_SELECTOR}'="true" | .metadata.labels.'${MATCH_SELECTOR}'="true" | .spec.template.metadata.labels.'${MATCH_SELECTOR}'="true"' | oc -n ${NAMESPACE} replace --force -f -
	  
   fi

   echo "Re-applying the deployment - modified deploy json follows..."
   
   cat deployed-3.json
   
   oc -n ${NAMESPACE} replace --force -f deployed-3.json
   
   set -x
   if oc rollout status deploy/${DEPLOYMENT_NAME} --watch=true --request-timeout="1200s" --namespace ${NAMESPACE}; then
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
