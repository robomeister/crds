#!/bin/bash
echo "*** DEPLOYMENT VARS ***"
echo ${NAME}
echo ${NAMESPACE}
echo ${PIPELINE_IMAGE_URL}
echo ${EPHEMERAL}
echo ${QMGR_NAME}
echo "*** DEPLOYMENT VARS ***"

rm "deploy-simq.json"

#URL="https://raw.githubusercontent.com/robomeister/crds/master/deploy-simq.json"
#echo "wget --no-cache --no-cookies ${URL}"
#wget --no-cache --no-cookies "https://raw.githubusercontent.com/robomeister/crds/master/deploy-simq.jso"
#echo "**** after wget ***"

echo " getting json via curl"
curl https://raw.githubusercontent.com/robomeister/crds/master/deploy-simq.json >deploy-simq.json

cat deploy-mq-esb.json

echo "Creating JSON"
if [[ -z ${EPHEMERAL} ]];
then
   echo "using storage class: ${STORAGE_CLASS}"
   cat deploy-simq.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' >deploy-simq-1.json
else
   echo "using ephemeral storage"
   cat deploy-simq.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' >deploy-simq-1.json
fi

if [[ -z ${QMGR_NAME} ]];
then
   echo "Using default QM name QM1"
   cat deploy-simq-1.json >deploy-simq-2.json
else
   echo "setting qmgr name to: ${QMGR_NAME}"
   cat deploy-simq-1.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.name="'${QMGR_NAME}'"' >deploy-simq-2.json
fi

if [[ -z ${MQSC_CONFIGMAP} ]];
then
   echo "no config map specified"
   cat deploy-simq-2.json >deploy-simq-3.json
else
   echo "configuring config map for mqsc"
   cat deploy-simq-2.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.mqsc[0].configMap.name="'${NAME}'" | .spec.queueManager.mqsc[0].configMap.items[0]="40-'${NAME}'.mqsc"' >deploy-simq-3.json
fi

if [[ -z ${PRIMARY_NODE} ]];
then
   
   echo "Not assigning qmgr to specific worker node"
   cat deploy-simq-3.json > deploy-simq-6.json
   
else
	echo "Primary node assignd, checking for secondary"

	if [[ -z ${SECONDARY_NODE} ]];
	then
	   echo "Please set both PRIMARY_NODE and SECONDARY_NODE environment variables"
	   exit 1
	else
	   echo "Setting spec.affinity.nodeAffinity"
	   cat deploy-simq-3.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${PRIMARY_NODE}'","'${SECONDARY_NODE}'"]}]' > deploy-simq-4.json
	   cat deploy-simq-4.json | jq '.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].preference.matchExpressions += [{"key":"workernode","operator":"In", "values":["'${PRIMARY_NODE}'"]}]' > deploy-simq-5.json
	   cat deploy-simq-5.json | jq '.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].weight= 1' > deploy-simq-6.json
	fi   
fi

if [[ -z ${MAX_CPU} ]];
then
	  cp  deploy-simq-6.json deploy-simq-7.json
else
      echo "Setting max cpu to: ${MAX_CPU}"
      cat deploy-simq-6.json | jq '.spec.queueManager.resources.limits.cpu="'${MAX_CPU}'"' > deploy-simq-7.json
fi

if [[ -z ${MAX_MEMORY} ]];
then
      cp  deploy-simq-7.json deploy-simq-8.json
else
      echo "Setting max memory to: ${MAX_MEMORY}"
      cat deploy-simq-7.json | jq '.spec.queueManager.resources.limits.memory="'${MAX_MEMORY}'"' > deploy-simq-8.json
fi

if [[ -z ${MIN_CPU} ]];
then
      cp  deploy-simq-8.json deploy-simq-9.json
else
      echo "Setting min cpu to: ${MIN_CPU}"
      cat deploy-simq-8.json | jq '.spec.queueManager.resources.requests.cpu="'${MIN_CPU}'"' > deploy-simq-9.json
fi

if [[ -z ${MIN_MEMORY} ]];
then
      cp  deploy-simq-9.json deploy-simq-10.json
else
      echo "Setting min memory to: ${MIN_MEMORY}"
      cat deploy-simq-9.json | jq '.spec.queueManager.resources.requests.memory="'${MIN_MEMORY}'"' > deploy-simq-10.json
fi

echo "*** customized/deployable json is as follows ***"
cat deploy-simq-10.json

#echo "deploying - dry run"
#oc apply -f deploy-simq-10.json --dry-run -o yaml 

echo "deploying"
oc apply -f deploy-simq-10.json 
