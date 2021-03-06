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

DEPLOYMENT_NAME=${NAMESPACE}-${IDS_PROJECT_NAME}-is

rm deploy-ace-esb.json

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-esb.json

cp deploy-ace-esb.json deploy.json

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
      echo "no server-conf configuration added"
      cp  deploy.json deploy1.json
else
      echo "adding server-conf: ${SERVER_CONF}"
      cat deploy.json | jq '.spec.configurations += ["'${SERVER_CONF}'"]' > deploy1.json
fi

if [[ -z ${MAX_CPU} ]];
then
      echo "using default max cpu"
      cat deploy1.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${DEFAULT_MAX_CPU}'"' > deploy2.json
else
      echo "setting max cpu: ${MAX_CPU}"
      cat deploy1.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${MAX_CPU}'"' > deploy2.json
fi

if [[ -z ${MAX_MEMORY} ]];
then
      echo "using default max memory"
      cat deploy2.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${DEFAULT_MAX_MEMORY}'"' > deploy3.json
else
      echo "setting max memory: ${MAX_MEMORY}"
      cat deploy2.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${MAX_MEMORY}'"' > deploy3.json
fi

if [[ -z ${MIN_CPU} ]];
then
      echo "using default min cpu"
      cat deploy3.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${DEFAULT_MIN_CPU}'"' > deploy4.json
else
      echo "setting max cpu: ${MIN_CPU}"
      cat deploy3.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${MIN_CPU}'"' > deploy4.json
fi

if [[ -z ${MIN_MEMORY} ]];
then
      echo "using default min memory"
      cat deploy4.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${DEFAULT_MIN_MEMORY}'"' > deploy5.json
else
      echo "setting min memory: ${MIN_MEMORY}"
      cat deploy4.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${MIN_MEMORY}'"' > deploy5.json
fi

if [[ -z ${WORKER_NODE} ]];
then
      echo "not setting worker node selector"
      cp  deploy5.json deploy6.json
else
      echo "setting worker node selector: ${WORKER_NODE}"
      cat deploy5.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${WORKER_NODE}'"]}]' > deploy6.json
fi

cat deploy6.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'" | .metadata.namespace = "'${NAMESPACE}'" | .spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deploy7.json

if [[ -z ${POLICY_CONF} ]];
then
      echo "no policy configuration applied"
      cp  deploy7.json deploy8.json
else
      echo "adding policy-conf: ${POLICY_CONF}" 
      cat deploy7.json | jq '.spec.configurations += ["'${POLICY_CONF}'"]' > deploy8.json
fi

if [[ -z ${DBPARMS_CONF} ]];
then
      echo "no dbparms configuration applied"
      cp  deploy8.json deploy9.json
else
      echo "adding dbparms-conf: ${DBPARMS_CONF}" 
      cat deploy8.json | jq '.spec.configurations += ["'${DBPARMS_CONF}'"]' > deploy9.json
fi

if [[ -z ${GENERIC_CONF} ]];
then
      echo "no generic configuration applied"
      cp  deploy9.json deploy10.json
else
      echo "adding generic-conf: ${GENERIC_CONF}" 
      cat deploy9.json | jq '.spec.configurations += ["'${GENERIC_CONF}'"]' > deploy10.json
fi

echo "*** begin: modified json to deploy ***"
cat deploy10.json
echo "*** end: modified json to deploy ***"

echo "DEPLOYING..."
oc apply -f deploy10.json 

echo "$(date) - waiting for deploy to take"
sleep 15s

set -x
if oc rollout status deploy/${DEPLOYMENT_NAME} --watch=true --request-timeout="1800s" --namespace ${NAMESPACE}; then
  STATUS="pass"
else
  STATUS="fail"
fi
echo "$(date) - done waiting"
set +x

if [ "$STATUS" == "fail" ]; then
  echo "DEPLOYMENT FAILED"
  exit 1
else
   echo "$(date) - waiting for deploy to take"
   sleep 60s
   echo "$(date) - done waiting"

   echo "Getting deployment json..."

   oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json

   #echo "Deployment json is as follows: "
   #cat deployed.json

   if [[ $(cat deployed.json|grep varlog|wc -l) -eq 0 ]];
   then
      echo "No varlog mount/claim found in deployment" 
      if [[ -z ${MATCH_SELECTOR} ]];
      then
         echo "No Match Selector Specified.  Enabling metrics and setting log4j PVC..."
	     cat deployed.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deployed-1.json
         cat deployed-1.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-log4j"} }]' >deployed-2.json
         cat deployed-2.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deployed-3.json
      else
         echo "Updating Match Selectors and enabling metrics and setting log4j PVC..."
         cat deployed.json  | jq '.spec.template.spec.containers[0].env[1].value="true" | .spec.selector.matchLabels.'${MATCH_SELECTOR}'="true" | .metadata.labels.'${MATCH_SELECTOR}'="true" | .spec.template.metadata.labels.'${MATCH_SELECTOR}'="true"' >deployed-0.json
	     cat deployed-0.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deployed-1.json
         cat deployed-1.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-log4j"} }]' >deployed-2.json
         cat deployed-2.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deployed-3.json
      fi

      echo "Re-applying the deployment - modified deploy json follows..."
   
      #cat deployed-3.json
   
      oc replace --force --wait=true -n ${NAMESPACE} -f deployed-3.json

      #oc apply -f deployed-3.json

      #sleep 30s
   
      echo "Deployed json is as follows:"
	  
      oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json
		
      cat deployed.json 
		
      echo "DEPLOYMENT COMPLETED - Check Pod is running in namespace ${NAMESPACE}"
   else
      echo "No re-deploy required - volume mount and claim found - Check Pod is running in namespace ${NAMESPACE}"
   fi   
   exit 0
fi   
   