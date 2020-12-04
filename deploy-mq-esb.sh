#!/bin/bash
echo "*** DEPLOYMENT VARS ***"
echo ${NAME}
echo ${NAMESPACE}
echo ${PIPELINE_IMAGE_URL}
echo ${EPHEMERAL}
echo ${QMGR_NAME}
echo "*** DEPLOYMENT VARS ***"

rm "deploy-mq-esb.json"

#URL="https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq-esb.json"
#echo "wget --no-cache --no-cookies ${URL}"
#wget --no-cache --no-cookies "https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq-esb.jso"
#echo "**** after wget ***"

echo " getting json via curl"
curl https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq-esb.json >deploy-mq-esb.json

cat deploy-mq-esb.json

echo "Creating JSON"
if [[ -z ${EPHEMERAL} ]];
then
   echo "using storage class: ${STORAGE_CLASS}"
   cat deploy-mq-esb.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' >deploy-mq-esb-1.json
else
   echo "using ephemeral storage"
   cat deploy-mq-esb.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' >deploy-mq-esb-1.json
fi

if [[ -z ${QMGR_NAME} ]];
then
   echo "Using default QM name QM1"
   cat deploy-mq-esb-1.json >deploy-mq-esb-2.json
else
   echo "setting qmgr name to: ${QMGR_NAME}"
   cat deploy-mq-esb-1.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.name="'${QMGR_NAME}'"' >deploy-mq-esb-2.json
fi

if [[ -z ${MQSC_CONFIGMAP} ]];
then
   echo "no config map specified"
   cat deploy-mq-esb-2.json >deploy-mq-esb-3.json
else
   echo "configuring config map for mqsc"
   cat deploy-mq-esb-2.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.mqsc[0].configMap.name="'${NAME}'" | .spec.queueManager.mqsc[0].configMap.items[0]="20-'${NAME}'.mqsc"' >deploy-mq-esb-3.json
fi

if [[ -z ${PRIMARY_NODE} ]];
then
   
   echo "Not assigning qmgr to specific worker node"
   cat deploy-mq-esb-3.json > deploy-mq-esb-6.json
   
else
	echo "Primary node assignd, checking for secondary"

	if [[ -z ${SECONDARY_NODE} ]];
	then
	   echo "Please set both PRIMARY_NODE and SECONDARY_NODE environment variables"
	   exit 1
	else
	   echo "Setting spec.affinity.nodeAffinity"
	   cat deploy-mq-esb-3.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${PRIMARY_NODE}'","'${SECONDARY_NODE}'"]}]' > deploy-mq-esb-4.json
	   cat deploy-mq-esb-4.json | jq '.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].preference.matchExpressions += [{"key":"workernode","operator":"In", "values":["'${PRIMARY_NODE}'"]}]' > deploy-mq-esb-5.json
	   cat deploy-mq-esb-5.json | jq '.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].weight= 1' > deploy-mq-esb-6.json
	fi   
fi

if [[ -z ${MAX_CPU} ]];
then
	  cp  deploy-mq-esb-6.json deploy-mq-esb-7.json
else
      echo "Setting max cpu to: ${MAX_CPU}"
      cat deploy-mq-esb-6.json | jq '.spec.queueManager.resources.limits.cpu="'${MAX_CPU}'"' > deploy-mq-esb-7.json
fi

if [[ -z ${MAX_MEMORY} ]];
then
      cp  deploy-mq-esb-7.json deploy-mq-esb-8.json
else
      echo "Setting max memory to: ${MAX_MEMORY}"
      cat deploy-mq-esb-7.json | jq '.spec.queueManager.resources.limits.memory="'${MAX_MEMORY}'"' > deploy-mq-esb-8.json
fi

if [[ -z ${MIN_CPU} ]];
then
      cp  deploy-mq-esb-8.json deploy-mq-esb-9.json
else
      echo "Setting min cpu to: ${MIN_CPU}"
      cat deploy-mq-esb-8.json | jq '.spec.queueManager.resources.requests.cpu="'${MIN_CPU}'"' > deploy-mq-esb-9.json
fi

if [[ -z ${MIN_MEMORY} ]];
then
      cp  deploy-mq-esb-9.json deploy-mq-esb-10.json
else
      echo "Setting min memory to: ${MIN_MEMORY}"
      cat deploy-mq-esb-9.json | jq '.spec.queueManager.resources.requests.memory="'${MIN_MEMORY}'"' > deploy-mq-esb-10.json
fi

echo "*** customized/deployable json is as follows ***"
cat deploy-mq-esb-10.json

echo "deploying - dry run"
oc apply -f deploy-mq-esb-10.json --dry-run -o yaml 

echo "deploying"
oc apply -f deploy-mq-esb-10.json 

echo "wait a few seconds for service to create"
sleep 9

#echo "oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = '${SERVICEHOST}'' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -"
#oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = "'${SERVICEHOST}'"' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -
