#!/bin/bash

echo "*** DEPLOYMENT VARS ***"
echo ${NAME}
echo ${NAMESPACE}
echo ${PIPELINE_IMAGE_URL}
echo ${EPHEMERAL}
echo ${QMGR_NAME}
echo "*** DEPLOYMENT VARS ***"

rm deploy-mq-esb.json

#URL="https://raw.githubusercontent.com/robomeister/crds/master/deploy-mq-esb.json"

#echo "wget --no-cache --no-cookies ${URL}"
#wget --no-cache --no-cookies ${URL}
#echo "**** after wget ***"

echo "{
    "apiVersion": "mq.ibm.com/v1beta1",
    "kind": "QueueManager",
    "metadata": {
        "name": "name",
        "namespace": "namespace"
    },
    "spec": {
        "imagePullSecrets": [ { "name": "all-icr-io" } ],
        "license": {
            "accept": true,
            "license": "L-RJON-BN7PN3",
            "metric": "VirtualProcessorCore",
            "use": "Production"
        },
        "queueManager": {
            "availability": {
                "type": "SingleInstance"
            },
            "image": "image",
            "imagePullPolicy": "IfNotPresent",
            "metrics": {
                "enabled": false
            },
            "name": "QM1",
            "resources": {
                "limits": {
                    "cpu": "2",
                    "memory": "2048Mi"
                },
                "requests": {
                    "cpu": "1",
                    "memory": "1024Mi"
                }
            },
            "storage": {
                "queueManager": {
                    "class": "ibmc-block-custom-high-iops",
                    "size": "40Gi",
                    "type": "persistent-claim"
                }
            }
        },
        "template": {
            "pod": {
                "containers": [
                    {
                        "env": [
                            {
                                "name": "MQSNOAUT",
                                "value": "yes"
                            }
                        ],
                        "name": "qmgr"
                    }
                ]
            }
        },
        "tracing": {
            "enabled": false,
            "namespace" : ""
        },
        "version": "9.1.5.0-r2",
        "web": {
            "enabled": false
        }
    }
}
" >deploy-mq-esb.json
cat deploy-mq-esb.json



echo " "
echo "Creating JSON"

if [[ -z ${EPHEMERAL} ]];
then
   
   echo "cat deploy-mq-esb.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.class='${STORAGE_CLASS}'' | oc apply -f - "
   cat deploy-mq-esb.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.class="'${STORAGE_CLASS}'"' >deploy-mq-esb-1.json
else
   echo "cat deploy-mq-esb.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.type='ephemeral'' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f - "
   cat deploy-mq-esb.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.storage.queueManager.type="ephemeral"' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' >deploy-mq-esb-1.json
fi

if [[ -z ${QMGR_NAME} ]];
then
   echo "Using default QM name QM1"
   cat deploy-mq-esb-1.json >deploy-mq-esb-2.json
else
   echo "cat deploy-mq-esb.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.type='ephemeral'' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f - "
   cat deploy-mq-esb-1.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.name="'${QMGR_NAME}'"' >deploy-mq-esb-2.json
fi

if [[ -z ${MQSC_CONFIGMAP} ]];
then
   echo "no config map specified"
   cat deploy-mq-esb-2.json >deploy-mq-esb-3.json
else
   echo "cat deploy-mq.json | jq '.metadata.name = '${NAMESPACE}'-'${NAME}'' | jq '.metadata.namespace = '${NAMESPACE}'' | jq '.spec.queueManager.image='${PIPELINE_IMAGE_URL}'' |  jq '.spec.queueManager.storage.queueManager.type='ephemeral'' | jq 'del(.spec.queueManager.storage.queueManager.size)' | jq 'del(.spec.queueManager.storage.queueManager.class)' | oc apply -f - "
   cat deploy-mq-esb-2.json | jq '.metadata.name = "'${NAMESPACE}'-'${NAME}'"' | jq '.metadata.namespace = "'${NAMESPACE}'"' | jq '.spec.queueManager.image="'${PIPELINE_IMAGE_URL}'"' |  jq '.spec.queueManager.mqsc[0].configMap.name="'${NAME}'" | .spec.queueManager.mqsc[0].configMap.items[0]="z-'${NAME}'.mqsc"' >deploy-mq-esb-3.json
fi


echo "deploying - dry run"
cat deploy-mq-esb-3.json | oc apply -f - --dry-run -o yaml 

echo "deploying "
cat deploy-mq-esb-3.json | oc apply -f -  


echo "wait a few seconds for service to create"
sleep 9

echo "oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = '${SERVICEHOST}'' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -"
#oc -n ${NAMESPACE} get service ${NAMESPACE}-${NAME}-ibm-mq -o json | jq '.metadata.name = "'${SERVICEHOST}'"' | jq 'del(.spec.clusterIP,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.selfLink,.metadata.uid,.status)' | oc -n ${NAMESPACE} apply -f -
