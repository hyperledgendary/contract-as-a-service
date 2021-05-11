# Build the Docker Images

# Use the current working directory as the home dir
export HOME_DIR  := `pwd`

# Builds the docker image for the chaincode, and tags/pushes this to the Container Registry
# Currently set to push to IBM staging
buildcontract LANG:
    docker build -t caasdemo-{{LANG}} ./{{LANG}}-contract/
    docker tag caasdemo-{{LANG}} stg.icr.io/ibp_caas/caasdemo-{{LANG}}:latest
    docker push stg.icr.io/ibp_caas/caasdemo-{{LANG}}:latest

# Deploy the chaincode in it's own K8S namespace, and configure IBP to use that chaincode
# Note the contract version and sequence
deploycaas LANG:
    ansible-playbook infrastructure/playbooks/002-setup-k8s-chaincode.yml \
        --extra-vars peer_prefix=dbpeer \
        --extra-vars smart_contract_name=caas-cc-{{LANG}} \
        --extra-vars home_dir=${HOME_DIR} 
    ansible-playbook infrastructure/playbooks/003-start-k8s-chaincode.yml \
        --extra-vars home_dir=${HOME_DIR} \
        --extra-vars lang={{LANG}} \
        --extra-vars peer_prefix=dbpeer \
        --extra-vars smart_contract_package=caas-cc-{{LANG}}.tgz \
        --extra-vars smart_contract_name=caas-cc-{{LANG}} \
        --extra-vars smart_contract_version=1 \
        --extra-vars smart_contract_sequence=1 \
        --extra-vars chaincode_docker_image=stg.icr.io/ibp_caas/caasdemo-{{LANG}}:latest

# This the managed way of deploying chaincode
deploymanaged LANG:
    ansible-playbook infrastructure/playbooks/21-commit-chaincode.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg \
        --extra-vars smart_contract_name=managed-cc-{{LANG}} \
        --extra-vars smart_contract_version=1 \
        --extra-vars smart_contract_sequence=1 \
#    ./scripts/pkgcc.sh -l managedcc -t node ./node-contract
#    ansible-playbook infrastructure/playbooks/19-install-and-approve-chaincode.yml \
#        --extra-vars wallet_dir=${HOME_DIR}/_cfg \
#        --extra-vars smart_contract_name=managedcc \
#        --extra-vars smart_contract_version=1 \
#        --extra-vars smart_contract_sequence=1 \
#        --extra-vars smart_contract_package=${HOME_DIR}/managedcc.tgz


# This creates an application identity that can be used to interact via client applications
registerapp:
    ansible-playbook infrastructure/playbooks/22-register-application.yml \
        --extra-vars smart_contract_name=managedcc \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg

# This builds the Fabric Network - Peers, CAs, Orderers and creates the admin identities
network: clean
    ansible-playbook infrastructure/playbooks/01-create-ordering-organization-components.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg
    ansible-playbook infrastructure/playbooks/02-create-endorsing-organization-components.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg
    ansible-playbook infrastructure/playbooks/05-enable-capabilities.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg
    ansible-playbook infrastructure/playbooks/06-add-organization-to-consortium.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg
    ansible-playbook infrastructure/playbooks/09-create-channel.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg
    ansible-playbook infrastructure/playbooks/10-join-peer-to-channel.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg
    ansible-playbook infrastructure/playbooks/11-add-anchor-peer-to-channel.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg

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
    ansible-playbook infrastructure/playbooks/002-k8s-cc-tls-setup.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg \
        --extra-vars enroll_id=dbpeer \
        --extra-vars name=dbpeer
    ansible-playbook infrastructure/playbooks/002-k8s-cc-tls-setup.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg \
        --extra-vars enroll_id=dbpeer-caas-cc-{{LANG}}-srvc.caasdemo 	\
        --extra-vars name=dbpeer-caas-cc-{{LANG}}-srvc.caasdemo

# removes the _cfg directory where wallets, connection profiles etc are stored.
clean:
    rm -rf _cfg; mkdir -p _cfg

# Ping the contract working as DigiBank
ping LANG:
    WALLET_DIR=${HOME_DIR}/_cfg/_wallets/DigiBank ID_NAME=ping  \
    CONTRACT=caas-cc-{{LANG}} \
    CHANNEL=caasnetwork \
    GATEWAY_PROFILE="${HOME_DIR}/_cfg/DigiBank Gateway.json"    \
    node client-app/metadata/index.js
