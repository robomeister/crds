#!/bin/bash

echo "DEPLOYMENT VARS"
echo ${NAME}
echo ${NAMESPACE}
echo ${PIPELINE_IMAGE_URL}

rm deploy-mq.json

echo "wget --no-cache --no-cookies https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq.json"
wget --no-cache --no-cookies https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq.json

cat deploy-mq.json



echo " "
echo "Building Deploy json"

if [[ -z ${EPHEMERAL} ]];
then
   
   #echo "cat deploy-mq.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.class='${STORAGE_CLASS}'' | oc apply -f - "
   #cat deploy-mq.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |   jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' | oc apply -f - --dry-run -o yaml
   #cat deploy-mq.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' | oc apply -f -
   
   echo "Using storage class: ${STORAGE_CLASS}"
   cat deploy-mq.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' > deploy-mq-1.json
   
else
   #echo "cat deploy-mq.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.type='ephemeral'' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f - "
   #cat deploy-mq.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f - --dry-run -o yaml
   #cat deploy-mq.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f -
   echo "using ephemeral storage"
   cat deploy-mq.json > cat deploy-mq-1.json
fi

if [[ -z ${PRIMARY_NODE} ]];
then
   
   echo "Not assigning qmgr to specific worker node"
   cat deploy-mq-1.json > deploy-mq-3.json
   
else
	if [[ -z ${SECONDARY_NODE} ]];
	then
	   echo "Please set both PRIMARY_NODE and SECONDARY_NODE environment variables"
	   exit 1
	else
	   echo "Setting spec.affinity.nodeAffinity"
	   cat deploy-mq-1.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${PRIMARY_NODE}'","'${SECONDARY_NODE}'"]}]' > deploy-mq-2.json
	   cat deploy-mq-2.json | jq '.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${PRIMARY_NODE}'"]}]' > deploy-mq-3.json
	fi   
fi

echo " "
echo "Deploying following json"
cat deploy-mq-3.json
echo " "
echo "Deploy dry Run"

oc apply -f deploy-mq-3.json --dry-run -o yaml 
 
echo " "
echo "Deploying..."

oc apply -f deploy-mq-3.json -o yaml 

#echo "wait a few seconds for service to create"
#sleep 30

#echo "oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = '${SERVICEHOST}'' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -"
#oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = "'${SERVICEHOST}'"' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -
