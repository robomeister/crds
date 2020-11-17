#!/bin/bash

echo "DEPLOYMENT VARS"
echo ${NAME}
echo ${NAMESPACE}
echo ${PIPELINE_IMAGE_URL}
echo ${EPHEMERAL}
echo ${QMGR_NAME}

rm deploy-mq-sap.json

echo "wget --no-cache --no-cookies https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq-sap.json"
wget --no-cache --no-cookies https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq-sap.json

cat deploy-mq-sap.json



echo " "
echo "DEPLOYING"

if [[ -z ${EPHEMERAL} ]];
then
   # use storage class provided 
   echo "cat deploy-mq.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.class='${STORAGE_CLASS}'' | oc apply -f - "
   cat deploy-mq-sap.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |   jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' | oc apply -f - --dry-run -o yaml
   cat deploy-mq-sap.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' | oc apply -f -
else
   # use ephemeral storage
   echo "cat deploy-mq-sap.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.type='ephemeral'' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f - "
   cat deploy-mq-sap.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f - --dry-run -o yaml
   cat deploy-mq-sap.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f -
fi

if [[ -z ${QMGR_NAME} ]];
then
   echo "Using default QM name QM1"
else
   # use qmgr name provided
   echo "cat deploy-mq.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.name='${QMGR_NAME}'' | oc apply -f - "
   cat deploy-mq-sap.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |   jq '.spec.queueManager.name="'${QMGR_NAME}'"' | oc apply -f - --dry-run -o yaml
   cat deploy-mq-sap.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.name="'${QMGR_NAME}'"' | oc apply -f -
fi


echo "wait a few seconds for service to create"
sleep 9

echo "oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = '${SERVICEHOST}'' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -"
#oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = "'${SERVICEHOST}'"' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -
