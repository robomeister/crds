#!/bin/bash

echo "DEPLOYMENT VARS"
echo "NAME: " ${NAME}
echo "NAMESPACE: " ${NAMESPACE}
echo "IMAGE: " ${PIPELINE_IMAGE_URL}
echo "QMGR NAME: " ${QMGR_NAME}
echo "CONFIG MAP: "  ${MQSC_CONFIGMAP}

rm deploy-mimq.json

echo "wget --no-cache --no-cookies https://raw.githubusercontent.com/robomeister/crds/master/deploy-mimq.json"
wget --no-cache --no-cookies https://raw.githubusercontent.com/robomeister/crds/master/deploy-mimq.json

echo " "
echo "Creating modified JSON"

cat deploy-mimq.json >deploy-mimq-1.json

echo "base json" 
cat deploy-mimq-1.json


if [[ -z ${QMGR_NAME} ]];
then
   echo "Using default QM name QM1"
   cat deploy-mimq-1.json >deploy-mimq-2.json
else
   echo "setting qmgr name to: ${QMGR_NAME}"
   #echo "cat deploy-mimq-1.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.name="'${QMGR_NAME}'"'"
   cat deploy-mimq-1.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.name="'${QMGR_NAME}'"' >deploy-mimq-2.json
fi

if [[ -z ${MQSC_CONFIGMAP} ]];
then
   echo "no config map specified"
   cat deploy-mimq-2.json >deploy-mimq-3.json
else
   echo "using configmap ${MQSC_CONFIGMAP}"
   #echo "cat deploy-mimq-2.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.mqsc[0].configMap.name="'${NAME}'" | .spec.queueManager.mqsc[0].configMap.items[0]="z-'${NAME}'.mqsc"'"
   cat deploy-mimq-2.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.mqsc[0].configMap.name="'${NAME}'" | .spec.queueManager.mqsc[0].configMap.items[0]="20-'${NAME}'.mqsc"' >deploy-mimq-3.json
fi

if [[ -z ${MAX_CPU} ]];
then
	  cp  deploy-mimq-3.json deploy-mimq-4.json
else
      echo "Setting max cpu to: ${MAX_CPU}"
      cat deploy-mimq-3.json | jq '.spec.queueManager.resources.limits.cpu="'${MAX_CPU}'"' > deploy-mimq-4.json
fi

if [[ -z ${MAX_MEMORY} ]];
then
      cp  deploy-mimq-4.json deploy-mimq-5.json
else
      echo "Setting max memory to: ${MAX_MEMORY}"
      cat deploy-mimq-4.json | jq '.spec.queueManager.resources.limits.memory="'${MAX_MEMORY}'"' > deploy-mimq-5.json
fi

if [[ -z ${MIN_CPU} ]];
then
      cp  deploy-mimq-5.json deploy-mimq-6.json
else
      echo "Setting min cpu to: ${MIN_CPU}"
      cat deploy-mimq-5.json | jq '.spec.queueManager.resources.requests.cpu="'${MIN_CPU}'"' > deploy-mimq-6.json
fi

if [[ -z ${MIN_MEMORY} ]];
then
      cp deploy-mimq-6.json deploy-mimq-7.json
else
      echo "Setting min memory to: ${MIN_MEMORY}"
      cat deploy-mimq-6.json | jq '.spec.queueManager.resources.requests.memory="'${MIN_MEMORY}'"' > deploy-mimq-7.json
fi

if [[ -z ${STORAGE_CLASS} ]];
then
   echo "using default storage class"
   cp deploy-mimq-7.json deploy-mimq-10.json
else
   echo "using storage class: ${STORAGE_CLASS}"
   cat deploy-miqm-7.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.persistedData.class="'${STORAGE_CLASS}'"' >deploy-mimq-8.json
   cat deploy-miqm-8.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' >deploy-mimq-9.json
   cat deploy-miqm-9.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.recoveryLogs.class="'${STORAGE_CLASS}'"' >deploy-mimq-10.json
fi

if [[ -z ${STORAGE_SIZE} ]];
then
   echo "using default disc size"
   cp deploy-mimq-10.json deploy-mimq-13.json
else
   echo "using storage size: ${STORAGE_SIZE}"
   cat deploy-miqm-10.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.persistedData.size="'${STORAGE_SIZE}'"' >deploy-mimq-11.json
   cat deploy-miqm-11.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.size="'${STORAGE_SIZE}'"' >deploy-mimq-12.json
   cat deploy-miqm-12.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.recoveryLogs.size="'${STORAGE_SIZE}'"' >deploy-mimq-13.json
fi


echo "*** customized/deployable json is as follows ***"
cat deploy-mimq-13.json

echo "deploying - dry run"
oc apply -f deploy-mimq-13.json --dry-run -o yaml 

echo "deploying"
oc apply -f deploy-mimq-13.json 

