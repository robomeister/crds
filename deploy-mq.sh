#!/bin/bash

echo "DEPLOYMENT VARS"
echo ${NAME}
echo ${NAMESPACE}
echo ${PIPELINE_IMAGE_URL}

wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace.json

cat deploy-mq.json

cat deploy-mq.json | jq '.metadata.name = "'${NAME}'-'${NAMESPACE}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |   jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' | oc apply -f - --dry-run -o yaml

echo " "
echo "DEPLOYING"
echo "cat deploy-mq.json | jq '.metadata.name = '${NAME}'-'${NAMESPACE}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.class='${STORAGE_CLASS}'' | oc apply -f - "
cat deploy-mq.json | jq '.metadata.name = "'${NAME}'-'${NAMESPACE}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' | oc apply -f - 

echo "wait a few seconds for service to create"
sleep 9

echo "oc -n ${NAMESPACE} get service ${NAME}-${NAMESPACE}-ibm-mq -o json | jq '.metadata.name = '${SERVICEHOST}'' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -"
oc -n ${NAMESPACE} get service ${NAME}-${NAMESPACE}-ibm-mq -o json | jq '.metadata.name = "'${SERVICEHOST}'"' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -
