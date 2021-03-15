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
	set -e
	ansible-playbook ansible-playbooks/001-iam-id.yml \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars cloud_api_key=${CLOUD_API_KEY}

nodedeploy:
	set -e
	ansible-playbook ansible-playbooks/002-setup-k8s-chaincode.yml \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars smart_contract_name=nodecontract \
		--extra-vars smart_contract_version=1 \
		--extra-vars smart_contract_sequence=1 \
		--extra-vars home_dir=${HOME_DIR}/_cfg \
		--extra-vars chaincode_docker_image=stg.icr.io/ibp_demo/caasdemo-node:latest

identity:
	set -e
	ansible-playbook ansible-playbooks/003-create-identity.yml \
		--extra-vars id_name="fred" \
		--extra-vars api_key=${IBP_KEY} \
		--extra-vars api_endpoint=${IBP_ENDPOINT} \
		--extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
		--extra-vars home_dir=${HOME_DIR} \
		--extra-vars network_name=CAASDEMO 

# runhfsc:
# 	echo "runhfsc --gateway ./_cfg/ansible/_gateways/CAASDEMO_CAASOrg1.json --wallet ./_cfg/ansible/_wallets/CAASDEMO_CAASOrg1 --user fred --channel caaschannel"

clean:
	rm -rf _cfg; mkdir -p _cfg