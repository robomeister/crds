#!/bin/bash

echo "DEPLOYMENT VARS"
echo ${NAME}
echo ${NAMESPACE}
echo ${PIPELINE_IMAGE_URL}
echo ${EPHEMERAL}
echo ${QMGR_NAME}
echo ${PRIMARY_NODE}
echo ${SECONDARY_NODE}

rm deploy-mq-tms.json

echo "wget --no-cache --no-cookies https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq-tms.json"
wget --no-cache --no-cookies https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq-tms.json

echo "base json" 
cat deploy-mq-tms.json
echo " "
echo "Creating modified JSON"

if [[ -z ${EPHEMERAL} ]];
then
   echo "using storage class: ${STORAGE_CLASS}"
   #echo "cat deploy-mq-tms.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"
   cat deploy-mq-tms.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' >deploy-mq-tms-1.json
else
   echo "using ephemeral storage"
   #echo "cat deploy-mq-tms.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)'"
   cat deploy-mq-tms.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' >deploy-mq-tms-1.json
fi

if [[ -z ${QMGR_NAME} ]];
then
   echo "Using default QM name QM1"
   cat deploy-mq-tms-1.json >deploy-mq-tms-2.json
else
   echo "setting qmgr name to: ${QMGR_NAME}"
   #echo "cat deploy-mq-tms-1.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.name="'${QMGR_NAME}'"'"
   cat deploy-mq-tms-1.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.name="'${QMGR_NAME}'"' >deploy-mq-tms-2.json
fi

if [[ -z ${MQSC_CONFIGMAP} ]];
then
   echo "no config map specified"
   cat deploy-mq-tms-2.json >deploy-mq-tms-3.json
else
   echo "using configmap ${MQSC_CONFIGMAP}"
   #echo "cat deploy-mq-tms-2.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.mqsc[0].configMap.name="'${NAME}'" | .spec.queueManager.mqsc[0].configMap.items[0]="z-'${NAME}'.mqsc"'"
   cat deploy-mq-tms-2.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.mqsc[0].configMap.name="'${NAME}'" | .spec.queueManager.mqsc[0].configMap.items[0]="20-'${NAME}'.mqsc"' >deploy-mq-tms-3.json
fi

if [[ -z ${PRIMARY_NODE} ]];
then
   
   echo "Not assigning qmgr to specific worker node"
   cat deploy-mq-tms-3.json > deploy-mq-tms-6.json
   
else
	echo "Primary node assignd, checking for secondary"

	if [[ -z ${SECONDARY_NODE} ]];
	then
	   echo "Please set both PRIMARY_NODE and SECONDARY_NODE environment variables"
	   exit 1
	else
	   echo "Setting spec.affinity.nodeAffinity"
	   cat deploy-mq-tms-3.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${PRIMARY_NODE}'","'${SECONDARY_NODE}'"]}]' > deploy-mq-tms-4.json
	   cat deploy-mq-tms-4.json | jq '.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].preference.matchExpressions += [{"key":"workernode","operator":"In", "values":["'${PRIMARY_NODE}'"]}]' > deploy-mq-tms-5.json
	   cat deploy-mq-tms-5.json | jq '.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].weight= 1' > deploy-mq-tms-6.json
	fi   
fi


echo "final json created "
echo "*** start of json to deploy  ***"
cat deploy-mq-tms-6.json
echo "*** end of json to deploy ***"
echo "deploying - dry run"
cat deploy-mq-tms-6.json | oc apply -f - --dry-run -o yaml 

echo "deploying"
cat deploy-mq-tms-6.json | oc apply -f -  

echo "wait a few seconds for service to create"
sleep 9

#echo "oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = '${SERVICEHOST}'' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -"
#oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = "'${SERVICEHOST}'"' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -

