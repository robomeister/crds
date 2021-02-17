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

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-albuc-pbx.json
wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-albuc-pbx-prod.json

case $NAMESPACE in
  *"pt"*|*"prod"*|*"dr"*)
    echo "Using PRODUCTION deployment json"
    cp deploy-ace-albuc-pbx-prod.json deploy.json
    ;;
  *)
    echo "Using non-prod deployment json"
    cp deploy-ace-albuc-pbx.json deploy.json
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

cat deploy6.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'" | .metadata.namespace = "'${NAMESPACE}'" | .spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deployment.json

echo "DRY RUN..."
oc apply -f deployment.json --dry-run -o yaml

echo "DEPLOYING..."
oc apply -f deployment.json

sleep 10s

DEPLOYMENT_NAME=${NAMESPACE}-${IDS_PROJECT_NAME}-is
echo "Deployment: " ${DEPLOYMENT_NAME}

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

