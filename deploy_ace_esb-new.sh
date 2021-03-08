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

DEPLOYMENT_NAME=${NAMESPACE}-${IDS_PROJECT_NAME}-is

BASE_ACE_CONFIGURATIONS="truststore.jks,aceclient.kdb,aceclient.sth,odbc.ini"

case $NAMESPACE in
  *"pt"*|*"prod"*|*"dr"*)
    echo "Setting PRODUCTION default memory and cpu"
	DEFAULT_MIN_CPU="1000m"
	DEFAULT_MAX_CPU="4000m"
    DEFAULT_MIN_MEMORY="1024Mi"
	DEFAULT_MAX_MEMORY="4096Mi"
    ;;
  *)
    echo "Setting NON-PRODUCTION default memory and cpu"
	DEFAULT_MIN_CPU="125m"
	DEFAULT_MAX_CPU="250m"
    DEFAULT_MIN_MEMORY="256Mi"
	DEFAULT_MAX_MEMORY="512Mi"
    ;;    
esac

rm deploy-ace-esb.json

oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME}

if oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME}; then
   echo "Deployment ${DEPLOYMENT_NAME} already exists - will modify deployment" 
   DEPLOYMENT_EXISTS="true"
   oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deploy-ace-esb.json
   if [[ $(cat deployed.json|grep varlog|wc -l) -eq 0 ]];
   then
      echo "No varlog mount/claim found in deployment" 
	  PVC_NEEDED = "true";
   else	 
      echo "varlog mount/claim found in deployment" 
	  PVC_NEEDED = "false";
   fi	  
   if [[ $(cat deployed.json|grep workernode|wc -l) -eq 0 ]];
   then
      echo "No worker node affinity found in deployment" 
	  WORKER_NEEDED = "true";
   else	 
      echo "Worker node affinity found in deployment" 
	  WORKER_NEEDED = "true";
   fi	  
else
   echo "Deployment ${DEPLOYMENT_NAME} does not exist - will deploy and then modify deployment"
   DEPLOYMENT_EXISTS="false"
   echo "Getting base json file from repro..."
   wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-esb.json
fi

cp deploy-ace-esb.json deploy.json
echo "Initial json before changes"
cat deploy.json

if [ "$DEPLOYMENT_EXISTS" == "true" ]; then
   echo "Deployment for integration server exists. Modify deployment and replacing..."
   
   if [[ -z ${MAX_CPU} ]];
   then
      echo "using default max cpu"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.limits.cpu="'${DEFAULT_MAX_CPU}'"' > deploy.json
   else
      echo "setting max cpu: ${MAX_CPU}"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.limits.cpu="'${MAX_CPU}'"' > deploy.json
   fi

   if [[ -z ${MAX_MEMORY} ]];
   then
      echo "using default max memory"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.limits.memory="'${DEFAULT_MAX_MEMORY}'"' > deploy.json
   else
      echo "setting max memory: ${MAX_MEMORY}"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.limits.memory="'${MAX_MEMORY}'"' > deploy.json
   fi   
   
   if [[ -z ${MIN_CPU} ]];
   then
      echo "using default min cpu"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.requests.cpu="'${DEFAULT_MIN_CPU}'"' > deploy.json
   else
      echo "setting max cpu: ${MIN_CPU}"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.requests.cpu="'${MIN_CPU}'"' > deploy.json
   fi

   if [[ -z ${MIN_MEMORY} ]];
   then
      echo "using default min memory"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.requests.memory="'${DEFAULT_MIN_MEMORY}'"' > deploy.json
   else
      echo "setting min memory: ${MIN_MEMORY}"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.requests.memory="'${MIN_MEMORY}'"' > deploy.json
   fi   
   
   if [[ -z ${WORKER_NODE} ]];
   then
      echo "not setting worker node selector"
   else
      echo "setting worker node selector: ${WORKER_NODE}"
	  cat deploy.json | jq -r 'del( .spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[] | select(.key == "workernode")  )' >deploy-no-worker.json
      cat deploy-no-worker.json | jq '.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${WORKER_NODE}'"]}]' > deploy.json
   fi

   cat deploy.json |  jq '.spec.template.spec.containers[0].image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deploy.json
   
   if [[ -z ${SERVER_CONF} ]];
   then
      echo "no server-conf configuration added"
	  ACE_CONFIGURATIONS=${BASE_ACE_CONFIGURATIONS}
   else
      echo "adding server-conf: ${SERVER_CONF}"
      ACE_CONFIGURATIONS="${BASE_ACE_CONFIGURATIONS},${SERVER_CONF}"
   fi

   if [[ -z ${POLICY_CONF} ]];
   then
      echo "no policy configuration applied"
   else
      echo "adding policy-conf: ${POLICY_CONF}" 
      ACE_CONFIGURATIONS="${ACE_CONFIGURATIONS},${POLICY_CONF}"
   fi

   if [[ -z ${DBPARMS_CONF} ]];
   then
      echo "no dbparms configuration applied"
   else
      echo "adding dbparms-conf: ${DBPARMS_CONF}" 
      ACE_CONFIGURATIONS="${ACE_CONFIGURATIONS},${DBPARMS_CONF}"
   fi

   if [[ -z ${GENERIC_CONF} ]];
   then
      echo "no generic configuration applied"
   else
      echo "adding generic-conf: ${GENERIC_CONF}" 
      ACE_CONFIGURATIONS="${ACE_CONFIGURATIONS},${GENERIC_CONF}"      
   fi
   
   #delete the ACE_CONFIGURATIONS env 
   cat  deploy.json | jq -r 'del( .spec.template.spec.containers[0].env[] | select(.name == "ACE_CONFIGURATIONS")  )' >deploy.json

   cat deploy.json | jq '.spec.template.spec.containers[0].env += [{"name": "ACE_CONFIGURATIONS", "value": "'${ACE_CONFIGURATIONS}'"}]' >deploy.json


   if [[ $(cat deploy.json | jq -r '.spec.template.spec.containers[0].env[] | select(.name=="ACE_ENABLE_METRICS") | .value') == "true" ]];
   then
      echo "Metrics already enabled"
   else
      echo "Enabling metrics"
      cat deploy.json | jq -r 'del( .spec.template.spec.containers[0].env[] | select(.name == "ACE_ENABLE_METRICS")  )' >deploy.json
      cat deploy.json | jq '.spec.template.spec.containers[0].env += [{"name": "ACE_ENABLE_METRICS", "value": "true"}]' >deploy.json
   fi

   if [[ $(cat deploy.json|grep varlog|wc -l) -eq 0 ]];
   then
      echo "adding volume mount and claim for log4j"
      cat deploy.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deploy.json
      cat deploy.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-log4j"} }]' >deploy.json
      cat deploy.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deploy.json
   else
      echo "Volume mount and claim already allocated"
   fi

   echo "Modified deployment is as follows"
   
   cat deploy.json

   echo "Re-applying the deployment"
   
   oc replace --force --wait=true -n ${NAMESPACE} -f deploy.json

   echo "$(date) - waiting for deploy to take"
   sleep 15s
   echo "$(date) - now getting deployment "
  
  
   echo "Deployed json is as follows:"
	  
   oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json
		
   cat deployed.json 
		
   echo "DEPLOYMENT COMPLETED - Check Pod is running in namespace ${NAMESPACE}"
   exit 0
else
   echo "Deployment for integration server does not exist. Deploying and the modifying deployment and replacing..."

   if [[ -z ${MAX_CPU} ]];
   then
      echo "using default max cpu"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${DEFAULT_MAX_CPU}'"' > deploy.json
   else
      echo "setting max cpu: ${MAX_CPU}"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${MAX_CPU}'"' > deploy.json
   fi

   if [[ -z ${MAX_MEMORY} ]];
   then
      echo "using default max memory"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${DEFAULT_MAX_MEMORY}'"' > deploy.json
   else
      echo "setting max memory: ${MAX_MEMORY}"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${MAX_MEMORY}'"' > deploy.json
   fi

   if [[ -z ${MIN_CPU} ]];
   then
      echo "using default min cpu"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${DEFAULT_MIN_CPU}'"' > deploy.json
   else
      echo "setting max cpu: ${MIN_CPU}"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${MIN_CPU}'"' > deploy.json
   fi

   if [[ -z ${MIN_MEMORY} ]];
   then
      echo "using default min memory"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${DEFAULT_MIN_MEMORY}'"' > deploy.json
   else
      echo "setting min memory: ${MIN_MEMORY}"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${MIN_MEMORY}'"' > deploy.json
   fi

   if [[ -z ${WORKER_NODE} ]];
   then
      echo "not setting worker node selector"
   else
      echo "setting worker node selector: ${WORKER_NODE}"
      cat deploy.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${WORKER_NODE}'"]}]' > deploy.json
   fi

   cat deploy.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'" | .metadata.namespace = "'${NAMESPACE}'" | .spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deploy.json

   if [[ -z ${POLICY_CONF} ]];
   then
      echo "no policy configuration applied"
   else
      echo "adding policy-conf: ${POLICY_CONF}" 
      cat deploy.json | jq '.spec.configurations += ["'${POLICY_CONF}'"]' > deploy.json
   fi

   if [[ -z ${DBPARMS_CONF} ]];
   then
      echo "no dbparms configuration applied"
   else
      echo "adding dbparms-conf: ${DBPARMS_CONF}" 
      cat deploy.json | jq '.spec.configurations += ["'${DBPARMS_CONF}'"]' > deploy.json
   fi

   if [[ -z ${GENERIC_CONF} ]];
   then
      echo "no generic configuration applied"
   else
      echo "adding generic-conf: ${GENERIC_CONF}" 
      cat deploy.json | jq '.spec.configurations += ["'${GENERIC_CONF}'"]' > deploy.json
   fi

   if [[ -z ${SERVER_CONF} ]];
   then
      echo "no server-conf configuration added"
   else
      echo "adding server-conf: ${SERVER_CONF}"
      cat deploy.json | jq '.spec.configurations += ["'${SERVER_CONF}'"]' > deploy.json
   fi
   
   echo "*** begin: modified json to deploy ***"
   cat deploy.json
   echo "*** end: modified json to deploy ***"

   echo "DEPLOYING..."
   oc apply -f deploy.json 

   echo "$(date) - waiting for deploy to take"
   sleep 15s
   echo "$(date) - now watching deployment "

   if oc rollout status deploy/${DEPLOYMENT_NAME} --watch=true --request-timeout="1800s" --namespace ${NAMESPACE}; 
   then
      STATUS="pass"
   else
      STATUS="fail"
   fi

   echo "$(date) - watch has completed"

   if [ "$STATUS" == "fail" ]; 
   then
      echo "DEPLOYMENT FAILED"
      exit 1
   else
      echo "$(date) - now waiting for deployment to complete"
      sleep 60s
      echo "$(date) - done waiting. Now getting deployment json..."

      oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json

      if [[ $(cat deployed.json|grep varlog|wc -l) -eq 0 ]];
      then
         echo "No varlog mount/claim found in deployment" 
         if [[ -z ${MATCH_SELECTOR} ]];
         then
            echo "No Match Selector Specified.  Enabling metrics and setting log4j PVC..."
	        cat deployed.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deployed.json
            cat deployed.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-log4j"} }]' >deployed.json
            cat deployed.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deployed.json
         else
            echo "Updating Match Selectors and enabling metrics and setting log4j PVC..."
            cat deployed.json  | jq '.spec.template.spec.containers[0].env[1].value="true" | .spec.selector.matchLabels.'${MATCH_SELECTOR}'="true" | .metadata.labels.'${MATCH_SELECTOR}'="true" | .spec.template.metadata.labels.'${MATCH_SELECTOR}'="true"' >deployed-0.json
	        cat deployed.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deployed.json
            cat deployed.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-log4j"} }]' >deployed.json
            cat deployed.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deployed.json
         fi

         echo "Re-applying the deployment"
   
         oc replace --force --wait=true -n ${NAMESPACE} -f deployed.json
  
         echo "Deployed json is as follows:"
	  
         oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json
		
         cat deployed.json 
		
         echo "DEPLOYMENT COMPLETED - Check Pod is running in namespace ${NAMESPACE}"
      else
         echo "No re-deploy required - volume mount and claim found - Check Pod is running in namespace ${NAMESPACE}"
      fi   
      exit 0
   fi
fi   
   