ibmcloud iam service-id-create demo-caas-id --description "Service ID for IBM Cloud Container Registry in Kubernetes caasdemo"
ibmcloud iam service-policy-create demo-caas-id --roles Reader --service-name container-registry
ibmcloud iam service-api-key-create demo-caas-key demo-caas-id --description "API key for service ID caasdemo" --file key.json
DOCKER_PASSWORD=$(cat key.json | jq -r '.apikey')
kubectl --namespace caasdemo create secret docker-registry pullimg-secret --docker-server=stg.icr.io --docker-username=iamapikey --docker-password=${DOCKER_PASSWORD} --docker-email=barney@flintstone.co
