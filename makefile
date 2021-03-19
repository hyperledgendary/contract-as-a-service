# Build the Docker Images

HOME_DIR=$(shell pwd)

.PHONY: nodecontract

nodecontract:
	docker build -t caasdemo-node ./node-contract/
	docker tag caasdemo-node stg.icr.io/ibp_demo/caasdemo-node:latest
	docker push stg.icr.io/ibp_demo/caasdemo-node:latest

.PHONY: javacontract
javacontract:
	docker build -t caasdemo-java ./java-contract/
	docker tag caasdemo-java stg.icr.io/ibp_demo/caasdemo-java:latest
	docker push stg.icr.io/ibp_demo/caasdemo-java:latest

network: clean
	scripts/createNetwork.sh

iamsetup:
	ansible-playbook ansible-playbooks/001-iam-id.yml \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars cloud_api_key=${CLOUD_API_KEY}

nodedeploy:
	ansible-playbook ansible-playbooks/002-setup-k8s-chaincode.yml \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars smart_contract_name=nodecontract \
		--extra-vars smart_contract_version=6 \
		--extra-vars smart_contract_sequence=14 \
		--extra-vars home_dir=${HOME_DIR} \
		--extra-vars chaincode_docker_image=stg.icr.io/ibp_demo/caasdemo-node:latest

javadeploy:
	ansible-playbook ansible-playbooks/002-setup-k8s-chaincode.yml \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars smart_contract_name=javacontract \
		--extra-vars smart_contract_version=2 \
		--extra-vars smart_contract_sequence=3 \
		--extra-vars home_dir=${HOME_DIR} \
		--extra-vars chaincode_docker_image=stg.icr.io/ibp_demo/caasdemo-java:latest

identity:
	ansible-playbook ansible-playbooks/003-create-identity.yml \
		--extra-vars id_name="fred" \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars home_dir=${HOME_DIR} \
		--extra-vars network_name=CAASDEMO 

tls:
	ansible-playbook ansible-playbooks/002-tls-setup-expr.yml \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars home_dir=${HOME_DIR} \
		--extra-vars enroll_id=org1peer \
		--extra-vars name=org1peer
	ansible-playbook ansible-playbooks/002-tls-setup-expr.yml \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars home_dir=${HOME_DIR} \
		--extra-vars enroll_id=nodecontract-srvc.caasdemo 	\
		--extra-vars name=nodecontract-srvc.caasdemo

clean:
	rm -rf _cfg; mkdir -p _cfg