# Build the Docker Images

# Use the current working directory as the home dir
export HOME_DIR  := `pwd`

# Builds the docker image for the chaincode, and tags/pushes this to the Container Registry
contract LANG:
    docker build -t caasdemo-{{LANG}} ./{{LANG}}-contract/
    docker tag caasdemo-{{LANG}} stg.icr.io/ibp_demo/caasdemo-{{LANG}}:latest
    docker push stg.icr.io/ibp_demo/caasdemo-{{LANG}}:latest

# Deploy the chaincode in it's own K8S namespace, and configure IBP to use that chaincode
# Note the contract version and sequence
deploy LANG:
    ansible-playbook ansible-playbooks/002-setup-k8s-chaincode.yml \
        --extra-vars api_key=${IBP_KEY} \
        --extra-vars api_endpoint=${IBP_ENDPOINT} \
        --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
        --extra-vars smart_contract_name={{LANG}}contract \
        --extra-vars smart_contract_version=6 \
        --extra-vars smart_contract_sequence=14 \
        --extra-vars home_dir=${HOME_DIR} \
        --extra-vars chaincode_docker_image=stg.icr.io/ibp_demo/caasdemo-{{LANG}}:latest

# This creates an application identity that can be used to interact via client applications
identity:
    ansible-playbook ansible-playbooks/003-create-identity.yml \
        --extra-vars id_name="fred" \
        --extra-vars api_key=${IBP_KEY} \
        --extra-vars api_endpoint=${IBP_ENDPOINT} \
        --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
        --extra-vars home_dir=${HOME_DIR} \
        --extra-vars network_name=CAASDEMO 


network: clean
    ansible-playbook ./ansible-playbooks/000-create-network.yml \
        --extra-vars api_key=${IBP_KEY} \
        --extra-vars api_endpoint=${IBP_ENDPOINT} \
        --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
        --extra-vars home_dir=${HOME_DIR}/_cfg

# Runs the setup to create an secret to use to pull the docker images for the chaincodes
# NOTE: there is a defect currently with the Ansible IBM Cloud playbooks that 
# means it's best to do this by hand with the CLI. (it's a one time setup)
iamsetup:
    ansible-playbook ansible-playbooks/001-iam-id.yml \
        --extra-vars api_key=${IBP_KEY} \
        --extra-vars api_endpoint=${IBP_ENDPOINT} \
        --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
        --extra-vars cloud_api_key=${CLOUD_API_KEY}

# For TLS, configure new Certificates approved by the Org1 CA.
tls LANG:
    ansible-playbook ansible-playbooks/002-tls-setup-expr.yml \
        --extra-vars api_key=${IBP_KEY} \
        --extra-vars api_endpoint=${IBP_ENDPOINT} \
        --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
        --extra-vars home_dir=${HOME_DIR} \
        --extra-vars enroll_id=org1peer{{LANG}} \
        --extra-vars name=org1peer{{LANG}}
    ansible-playbook ansible-playbooks/002-tls-setup-expr.yml \
        --extra-vars api_key=${IBP_KEY} \
        --extra-vars api_endpoint=${IBP_ENDPOINT} \
        --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
        --extra-vars home_dir=${HOME_DIR} \
        --extra-vars enroll_id={{LANG}}contract-srvc.caasdemo 	\
        --extra-vars name={{LANG}}contract-srvc.caasdemo

# removes the _cfg directory where wallets, connection profiles etc are stored. 
clean:
    rm -rf _cfg; mkdir -p _cfg
