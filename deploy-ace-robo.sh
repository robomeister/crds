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

rm deploy-ace-robo.json

wget --no-cache https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-robo.json

case $NAMESPACE in
  *"pt"*|*"prod"*|*"dr"*)
    echo "Using PRODUCTION deployment json"
    cp deploy-ace-robo.json deploy.json
    ;;
  *)
    echo "Using non-prod deployment json"
    cp deploy-ace-robo.json deploy.json
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
      echo "No Match Selector Specified.  Enabling metrics..."
      oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json | jq '.spec.template.spec.containers[0].env[1].value="true"' | oc -n ${NAMESPACE} replace --force -f -
   else
      echo "Updating Match Selectors and enabling metrics..."
      oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json | jq '.spec.template.spec.containers[0].env[1].value="true" | .spec.selector.matchLabels.'${MATCH_SELECTOR}'="true" | .metadata.labels.'${MATCH_SELECTOR}'="true" | .spec.template.metadata.labels.'${MATCH_SELECTOR}'="true"' | oc -n ${NAMESPACE} replace --force -f -
   fi

   echo "Re-applying the deployment..."
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
   
   if [[ -z ${PRIVATE_VLAN} ]]; then
     echo "Not Adding a Private IP"
   else
     echo "Adding Private IP"
     oc -n ${NAMESPACE} get service ${DEPLOYMENT_NAME} -o json > service.json
     cat service.json | jq 'del(.spec.clusterIP) | del(.metadata.managedFields) | del(.metadata.creationTimestamp) | del(.metadata.ownerReferences) | del(.metadata.resourceVersion) | del(.metadata.selfLink) | del(.metadata.uid) | .spec.type="LoadBalancer" | .spec.externalTrafficPolicy="Local" | .metadata.annotations."service.kubernetes.io/ibm-load-balancer-cloud-provider-enable-features"="ipvs" | .metadata.annotations."service.kubernetes.io/ibm-load-balancer-cloud-provider-ip-type"="private" | .metadata.annotations."service.kubernetes.io/ibm-load-balancer-cloud-provider-vlan"= "'${PRIVATE_VLAN}'" | .metadata.name=(.metadata.name+"-private")' > private-service.json

     if [[ -z ${PRIVATE_IP} ]]; 
     then
        echo "Grabbing randomly available IP"
        cp private-service.json private-service-2.json
     else
        echo "Applying ${PRIVATE_IP} to the service"
        cat private-service.json | jq '.spec.loadBalancerIP="'${PRIVATE_IP}'"' > private-service-2.json
     fi

     cat private-service-2.json
     oc apply -f private-service-2.json
   fi   
fi
