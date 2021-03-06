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

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-hlt.json
wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-hlt-prod.json

case $NAMESPACE in
  *"pt"*|*"prod"*|*"dr"*)
    echo "Using PRODUCTION deployment json"
    cp deploy-ace-hlt-prod.json deploy.json
    ;;
  *)
    echo "Using non-prod deployment json"
    cp deploy-ace-hlt.json deploy.json
    ;;    
esac

cat deploy.json

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
      cp  deploy1.json deploy2.json
else
      echo "setting max cpu: ${MAX_CPU}"
      cat deploy1.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${MAX_CPU}'"' > deploy2.json
fi

if [[ -z ${MAX_MEMORY} ]];
then
      echo "using default max memory"
      cp  deploy2.json deploy3.json
else
      echo "setting max memory: ${MAX_MEMORY}"
      cat deploy2.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${MAX_MEMORY}'"' > deploy3.json
fi

if [[ -z ${MIN_CPU} ]];
then
      echo "using default min cpu"
      cp  deploy3.json deploy4.json
else
      echo "setting max cpu: ${MIN_CPU}"
      cat deploy3.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${MIN_CPU}'"' > deploy4.json
fi

if [[ -z ${MIN_MEMORY} ]];
then
      echo "using default min memory"
      cp  deploy4.json deploy5.json
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

echo "DRY RUN..."
oc apply -f deploy10.json --dry-run -o yaml

echo "DEPLOYING..."
oc apply -f deploy10.json

sleep 10s

DEPLOYMENT_NAME=${NAMESPACE}-${IDS_PROJECT_NAME}-is

set -x
if oc rollout status deploy/${DEPLOYMENT_NAME} --watch=true --request-timeout="1800s" --namespace ${NAMESPACE}; then
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
