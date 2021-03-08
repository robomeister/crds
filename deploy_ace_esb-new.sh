#!/bin/bash

echo "$(date): $0 starting..."

# check for required anv vars
if [[ -z ${NAMESPACE} ]];
then
   echo "$(date): NAMESPACE environment variable is required."
   exit 1
fi

if [[ -z ${REPLICAS} ]];
then
   REPLICAS=1
fi

#set deployment name
DEPLOYMENT_NAME=${NAMESPACE}-${IDS_PROJECT_NAME}-is

#set base configurations - this should match configurations in json file 
BASE_ACE_CONFIGURATIONS="truststore.jks,aceclient.kdb,aceclient.sth,odbc.ini"

#set default memory and cpu 
case $NAMESPACE in
  *"pt"*|*"prod"*|*"dr"*)
    echo "$(date): Setting PRODUCTION default memory and cpu"
	DEFAULT_MIN_CPU="1000m"
	DEFAULT_MAX_CPU="4000m"
    DEFAULT_MIN_MEMORY="1024Mi"
	DEFAULT_MAX_MEMORY="4096Mi"
    ;;
  *)
    echo "$(date): Setting NON-PRODUCTION default memory and cpu"
	DEFAULT_MIN_CPU="125m"
	DEFAULT_MAX_CPU="250m"
    DEFAULT_MIN_MEMORY="256Mi"
	DEFAULT_MAX_MEMORY="512Mi"
    ;;    
esac

#clean up old files
rm deploy-ace-esb.json deploy.json deploy-1.json

#check if deployment already exists
oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME}

if oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME}; then
   echo "$(date): Deployment ${DEPLOYMENT_NAME} already exists - will modify deployment" 
   DEPLOYMENT_EXISTS="true"
   oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deploy-ace-esb.json
else
   echo "$(date): Deployment ${DEPLOYMENT_NAME} does not exist - will deploy and then modify deployment"
   DEPLOYMENT_EXISTS="false"
   echo "$(date): Getting base json file from repro..."
   wget https://raw.githubusercontent.com/robomeister/crds/master/deploy-ace-esb.json
fi

#set initial deploy file
cp deploy-ace-esb.json deploy.json

echo "$(date): Initial deployment json before changes"
cat deploy.json

if [ "$DEPLOYMENT_EXISTS" == "true" ]; then
   echo "$(date): Deployment for integration server exists. Modifying deployment and replacing..."
   
   if [[ -z ${MAX_CPU} ]];
   then
      echo "$(date): using default max cpu"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.limits.cpu="'${DEFAULT_MAX_CPU}'"' > deploy-1.json
   else
      echo "$(date): setting max cpu: ${MAX_CPU}"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.limits.cpu="'${MAX_CPU}'"' > deploy-1.json
   fi

   if [[ -z ${MAX_MEMORY} ]];
   then
      echo "$(date): using default max memory"
      cat deploy-1.json | jq '.spec.template.spec.containers[0].resources.limits.memory="'${DEFAULT_MAX_MEMORY}'"' > deploy.json
   else
      echo "$(date): setting max memory: ${MAX_MEMORY}"
      cat deploy-1.json | jq '.spec.template.spec.containers[0].resources.limits.memory="'${MAX_MEMORY}'"' > deploy.json
   fi   
   
   if [[ -z ${MIN_CPU} ]];
   then
      echo "$(date): using default min cpu"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.requests.cpu="'${DEFAULT_MIN_CPU}'"' > deploy-1.json
   else
      echo "$(date): setting max cpu: ${MIN_CPU}"
      cat deploy.json | jq '.spec.template.spec.containers[0].resources.requests.cpu="'${MIN_CPU}'"' > deploy-1.json
   fi

   if [[ -z ${MIN_MEMORY} ]];
   then
      echo "$(date): using default min memory"
      cat deploy-1.json | jq '.spec.template.spec.containers[0].resources.requests.memory="'${DEFAULT_MIN_MEMORY}'"' > deploy.json
   else
      echo "$(date): setting min memory: ${MIN_MEMORY}"
      cat deploy-1.json | jq '.spec.template.spec.containers[0].resources.requests.memory="'${MIN_MEMORY}'"' > deploy.json
   fi   
   
   if [[ -z ${WORKER_NODE} ]];
   then
      echo "$(date): not setting worker node selector"
   else
      echo "$(date): setting worker node selector: ${WORKER_NODE}"
	  cat deploy-1.json | jq -r 'del( .spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[] | select(.key == "workernode")  )' >deploy.json
      cat deploy.json | jq '.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${WORKER_NODE}'"]}]' > deploy-1.json
   fi

   cat deploy-1.json |  jq '.spec.template.spec.containers[0].image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deploy.json
   
   if [[ -z ${SERVER_CONF} ]];
   then
      echo "$(date): no server-conf configuration added"
	  ACE_CONFIGURATIONS=${BASE_ACE_CONFIGURATIONS}
   else
      echo "$(date): adding server-conf: ${SERVER_CONF}"
      ACE_CONFIGURATIONS="${BASE_ACE_CONFIGURATIONS},${SERVER_CONF}"
   fi

   if [[ -z ${POLICY_CONF} ]];
   then
      echo "$(date): no policy configuration applied"
   else
      echo "$(date): adding policy-conf: ${POLICY_CONF}" 
      ACE_CONFIGURATIONS="${ACE_CONFIGURATIONS},${POLICY_CONF}"
   fi

   if [[ -z ${DBPARMS_CONF} ]];
   then
      echo "$(date): no dbparms configuration applied"
   else
      echo "$(date): adding dbparms-conf: ${DBPARMS_CONF}" 
      ACE_CONFIGURATIONS="${ACE_CONFIGURATIONS},${DBPARMS_CONF}"
   fi

   if [[ -z ${GENERIC_CONF} ]];
   then
      echo "$(date): no generic configuration applied"
   else
      echo "$(date): adding generic-conf: ${GENERIC_CONF}" 
      ACE_CONFIGURATIONS="${ACE_CONFIGURATIONS},${GENERIC_CONF}"      
   fi
   
   #delete the ACE_CONFIGURATIONS env 
   cat  deploy.json | jq -r 'del( .spec.template.spec.containers[0].env[] | select(.name == "ACE_CONFIGURATIONS")  )' >deploy-1.json

   cat deploy-1.json | jq '.spec.template.spec.containers[0].env += [{"name": "ACE_CONFIGURATIONS", "value": "'${ACE_CONFIGURATIONS}'"}]' >deploy.json


   if [[ $(cat deploy.json | jq -r '.spec.template.spec.containers[0].env[] | select(.name=="ACE_ENABLE_METRICS") | .value') == "true" ]];
   then
      echo "$(date): Metrics already enabled"
   else
      echo "$(date): Enabling metrics"
      cat deploy.json | jq -r 'del( .spec.template.spec.containers[0].env[] | select(.name == "ACE_ENABLE_METRICS")  )' >deploy-1.json
      cat deploy-1.json | jq '.spec.template.spec.containers[0].env += [{"name": "ACE_ENABLE_METRICS", "value": "true"}]' >deploy.json
   fi

   if [[ $(cat deploy.json|grep varlog|wc -l) -eq 0 ]];
   then
      echo "$(date): adding volume mount and claim for log4j"
      cat deploy.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deploy-1.json
      cat deploy-1.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-log4j"} }]' >deploy.json
      cat deploy.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deploy-1.json
   else
      echo "$(date): Volume mount and claim already allocated"
	  mv deploy.json deploy-1.json
   fi

   echo "$(date): Modified deployment is as follows"
   
   cat deploy-1.json

   echo "$(date): Re-applying the deployment"
   
   oc replace --force --wait=true -n ${NAMESPACE} -f deploy-1.json

   echo "$(date): waiting for deploy to take"
   sleep 15s
   echo "$(date): now getting deployment "
  
  
   echo "$(date): Deployed json is as follows:"
	  
   oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json
		
   cat deployed.json 
		
   echo "$(date): DEPLOYMENT COMPLETED - Check Pod is running in namespace ${NAMESPACE}"
   exit 0
else
   echo "$(date): Deployment for integration server does not exist. Deploying and the modifying deployment and replacing..."

   if [[ -z ${MAX_CPU} ]];
   then
      echo "$(date): using default max cpu"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${DEFAULT_MAX_CPU}'"' > deploy-1.json
   else
      echo "$(date): setting max cpu: ${MAX_CPU}"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.limits.cpu="'${MAX_CPU}'"' > deploy-1.json
   fi

   if [[ -z ${MAX_MEMORY} ]];
   then
      echo "$(date): using default max memory"
      cat deploy-1.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${DEFAULT_MAX_MEMORY}'"' > deploy.json
   else
      echo "$(date): setting max memory: ${MAX_MEMORY}"
      cat deploy-1.json | jq '.spec.pod.containers.runtime.resources.limits.memory="'${MAX_MEMORY}'"' > deploy.json
   fi

   if [[ -z ${MIN_CPU} ]];
   then
      echo "$(date): using default min cpu"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${DEFAULT_MIN_CPU}'"' > deploy-1.json
   else
      echo "$(date): setting max cpu: ${MIN_CPU}"
      cat deploy.json | jq '.spec.pod.containers.runtime.resources.requests.cpu="'${MIN_CPU}'"' > deploy-1.json
   fi

   if [[ -z ${MIN_MEMORY} ]];
   then
      echo "$(date): using default min memory"
      cat deploy-1.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${DEFAULT_MIN_MEMORY}'"' > deploy.json
   else
      echo "$(date): setting min memory: ${MIN_MEMORY}"
      cat deploy-1.json | jq '.spec.pod.containers.runtime.resources.requests.memory="'${MIN_MEMORY}'"' > deploy.json
   fi

   if [[ -z ${WORKER_NODE} ]];
   then
      echo "$(date): not setting worker node selector"
	  mv deploy.json deploy-1.json
   else
      echo "$(date): setting worker node selector: ${WORKER_NODE}"
      cat deploy.json | jq '.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions += [{"key":"workernode","operator":"In", "values":["'${WORKER_NODE}'"]}]' > deploy-1.json
   fi

   cat deploy-1.json |  jq '.metadata.name = "'${NAMESPACE}'-'${IDS_PROJECT_NAME}'" | .metadata.namespace = "'${NAMESPACE}'" | .spec.pod.containers.runtime.image="'${PIPELINE_IMAGE_URL}'" | .spec.replicas='${REPLICAS}'' > deploy.json

   if [[ -z ${POLICY_CONF} ]];
   then
      echo "$(date): no policy configuration applied"
	  mv deploy.json deploy-1.json
   else
      echo "$(date): adding policy-conf: ${POLICY_CONF}" 
      cat deploy.json | jq '.spec.configurations += ["'${POLICY_CONF}'"]' > deploy-1.json
   fi

   if [[ -z ${DBPARMS_CONF} ]];
   then
      echo "$(date): no dbparms configuration applied"
	  mv deploy-1.json deploy.json
   else
      echo "$(date): adding dbparms-conf: ${DBPARMS_CONF}" 
      cat deploy-1.json | jq '.spec.configurations += ["'${DBPARMS_CONF}'"]' > deploy.json
   fi

   if [[ -z ${GENERIC_CONF} ]];
   then
      echo "$(date): no generic configuration applied"
	  mv deploy.json deploy-1.json
   else
      echo "$(date): adding generic-conf: ${GENERIC_CONF}" 
      cat deploy.json | jq '.spec.configurations += ["'${GENERIC_CONF}'"]' > deploy-1.json
   fi

   if [[ -z ${SERVER_CONF} ]];
   then
      echo "$(date): no server-conf configuration added"
	  mv deploy-1.json deploy.json
   else
      echo "$(date): adding server-conf: ${SERVER_CONF}"
      cat deploy-1.json | jq '.spec.configurations += ["'${SERVER_CONF}'"]' > deploy.json
   fi
   
   echo "*** begin: modified json to deploy ***"
   cat deploy.json
   echo "*** end: modified json to deploy ***"

   echo "$(date): Deploying..."
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
      echo "$(date): *** DEPLOYMENT FAILED ***"
      exit 1
   else
      echo "$(date): now waiting for deployment to complete"
      sleep 60s
      echo "$(date): done waiting. Now getting deployment json..."

      oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json

      if [[ $(cat deployed.json|grep varlog|wc -l) -eq 0 ]];
      then
         echo "$(date): No varlog mount/claim found in deployment" 
         if [[ -z ${MATCH_SELECTOR} ]];
         then
            echo "$(date): No Match Selector Specified.  Enabling metrics and setting log4j PVC..."
	        cat deployed.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deployed-1.json
            cat deployed-1.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-log4j"} }]' >deployed.json
            cat deployed.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deployed-1.json
			mv deploy-1.json deploy.json
         else
            echo "$(date): Updating Match Selectors and enabling metrics and setting log4j PVC..."
            cat deployed.json  | jq '.spec.template.spec.containers[0].env[1].value="true" | .spec.selector.matchLabels.'${MATCH_SELECTOR}'="true" | .metadata.labels.'${MATCH_SELECTOR}'="true" | .spec.template.metadata.labels.'${MATCH_SELECTOR}'="true"' >deployed-1.json
	        cat deployed-1.json | jq '.spec.template.spec.containers[0].volumeMounts += [{"mountPath": "/home/aceuser/ace-server/log4j/logs", "name": "varlog"}]' >deployed.json
            cat deployed.json | jq '.spec.template.spec.volumes += [{"name": "varlog", "persistentVolumeClaim": { "claimName": "logs-log4j"} }]' >deployed-1.json
            cat deployed-1.json | jq '.spec.template.spec.containers[0].env[1].value="true"' >deployed.json
         fi

         echo "$(date): Re-applying the deployment"
   
         oc replace --force --wait=true -n ${NAMESPACE} -f deployed.json
  
         echo "$(date): Deployed json is as follows:"
	  
         oc -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o json >deployed.json
		
         cat deployed.json 
		
         echo "$(date): DEPLOYMENT COMPLETED - Check Pod is running in namespace ${NAMESPACE}"
      else
         echo "$(date): No re-deploy required - volume mount and claim found - Check Pod is running in namespace ${NAMESPACE}"
      fi   
      exit 0
   fi
fi   
   