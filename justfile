# Build the Docker Images

# Use the current working directory as the home dir
export HOME_DIR  := `pwd`
export PLAYBOOK_DIR := 'infrastructure/ansible-ibp/playbooks'

# Builds the docker image for the chaincode, and tags/pushes this to the Container Registry
buildcontract LANG:
    docker build -t caasdemo-{{LANG}} ./{{LANG}}-contract/
    docker tag caasdemo-{{LANG}} uk.icr.io/ibp_caas/caasdemo-{{LANG}}:latest
    docker push uk.icr.io/ibp_caas/caasdemo-{{LANG}}:latest

#  Depending on the location of your cluster and registry - adjust the tag names
#    docker tag caasdemo-{{LANG}} stg.icr.io/ibp_caas/caasdemo-{{LANG}}:latest
#    docker push stg.icr.io/ibp_caas/caasdemo-{{LANG}}:latest

# Deploy the chaincode in it's own K8S namespace
# Note the contract version and sequence
deploycaas LANG:
    ansible-playbook {{PLAYBOOK_DIR}}/52-setup-k8s-chaincode.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars peer_prefix=dbpeer \
        --extra-vars smart_contract_name=caas-cc-{{LANG}} \
        --extra-vars home_dir=${HOME_DIR}
    ansible-playbook {{PLAYBOOK_DIR}}/53-start-k8s-chaincode.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars home_dir=${HOME_DIR} \
        --extra-vars lang={{LANG}} \
        --extra-vars peer_prefix=dbpeer \
        --extra-vars smart_contract_package=caas-cc-{{LANG}}.tgz \
        --extra-vars smart_contract_name=caas-cc-{{LANG}} \
        --extra-vars smart_contract_version=3 \
        --extra-vars smart_contract_sequence=3 \
        --extra-vars chaincode_docker_image=uk.icr.io/ibp_caas/caasdemo-{{LANG}}:latest

# This the managed way of deploying chaincode
# deploymanaged LANG:
#     ansible-playbook infrastructure/playbooks/21-commit-chaincode.yml \
#         --extra-vars "@auth-vars-ibp.yml" \
#         --extra-vars wallet_dir=${HOME_DIR}/_cfg \
#         --extra-vars smart_contract_name=managed-cc-{{LANG}} \
#         --extra-vars smart_contract_version=1 \
#         --extra-vars smart_contract_sequence=1 \
#    ./scripts/pkgcc.sh -l managedcc -t node ./node-contract
#    ansible-playbook infrastructure/playbooks/19-install-and-approve-chaincode.yml \
#        --extra-vars wallet_dir=${HOME_DIR}/_cfg \
#        --extra-vars smart_contract_name=managedcc \
#        --extra-vars smart_contract_version=1 \
#        --extra-vars smart_contract_sequence=1 \
#        --extra-vars smart_contract_package=${HOME_DIR}/managedcc.tgz


# This creates an application identity that can be used to interact via client applications
registerapp LANG:
    ansible-playbook {{PLAYBOOK_DIR}}/22-register-application.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars smart_contract_name=caas-cc-{{LANG}}  \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg

# This builds the Fabric Network - Peers, CAs, Orderers and creates the admin identities
startnetwork: clean
    #!/usr/bin/env bash
    set -euxo pipefail
    export IBP_ANSIBLE_LOG_FILENAME=ibp.log
    ansible-playbook {{PLAYBOOK_DIR}}/01-create-ordering-organization-components.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/02-create-endorsing-organization-components.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/05-enable-capabilities.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/06-add-organization-to-consortium.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/09-create-channel.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/10-join-peer-to-channel.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/11-add-anchor-peer-to-channel.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg


# Add MagentoCorp to the network
joinnetwork:
    ansible-playbook i{{PLAYBOOK_DIR}}/12-create-endorsing-organization-components.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/15-add-organization-to-channel.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/17-join-peer-to-channel.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg
    ansible-playbook {{PLAYBOOK_DIR}}/18-add-anchor-peer-to-channel.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg


# Runs the setup to create an secret to use to pull the docker images for the chaincodes
# NOTE: there is a defect currently with the Ansible IBM Cloud playbooks that
# means it's best to do this by hand with the CLI. (it's a one time setup)
iamsetup:
    ansible-playbook {{PLAYBOOK_DIR}}/50-iks-iam-id.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars "@auth-vars-cloud.yml"

# For TLS, configure new Certificates approved by the Org's CA
tls LANG="node" PEER="dbpeer":
    ansible-playbook {{PLAYBOOK_DIR}}/51-k8s-cc-tls-setup.yml \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars enroll_id={{PEER}}} \
        --extra-vars name={{PEER}}
    ansible-playbook {{PLAYBOOK_DIR}}/51-k8s-cc-tls-setup.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg \
        --extra-vars enroll_id={{PEER}}1-caas-cc-{{LANG}}-srvc.caasdemo 	\
        --extra-vars name={{PEER}}1-caas-cc-{{LANG}}-srvc.caasdemo
    ansible-playbook {{PLAYBOOK_DIR}}/51-k8s-cc-tls-setup.yml \
        --extra-vars "@auth-vars-ibp.yml" \
        --extra-vars wallet_dir=${HOME_DIR}/_cfg \
        --extra-vars enroll_id={{PEER}}2-caas-cc-{{LANG}}-srvc.caasdemo 	\
        --extra-vars name={{PEER}}2-caas-cc-{{LANG}}-srvc.caasdemo


# removes the _cfg directory where wallets, connection profiles etc are stored.
clean:
    rm -rf _cfg; mkdir -p _cfg; mkdir -p _cfg/ibp_wallet;

# Ping the contract working as DigiBank
ping LANG:
    WALLET_DIR=${HOME_DIR}/_cfg/_wallets/DigiBank ID_NAME=ping  \
    CONTRACT=caas-cc-{{LANG}} \
    CHANNEL=caasnetwork \
    GATEWAY_PROFILE="${HOME_DIR}/_cfg/ibp_wallet/DigiBank Gateway.json"    \
    node client-apps/metadata/index.js

# [WIP] Stress tests
createDriver LANG:
    WALLET_DIR=${HOME_DIR}/_cfg/_wallets/DigiBank ID_NAME=ping  \
    CONTRACT=caas-cc-{{LANG}} \
    CHANNEL=caasnetwork \
    GATEWAY_PROFILE="${HOME_DIR}/_cfg/ibp_wallet/DigiBank Gateway.json"    \
    node client-apps/driver/index.js

# For the staging environments this will need to be added
#        --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
checkIBP:
    ansible-playbook {{PLAYBOOK_DIR}}/00-console-health.yml \
        --extra-vars "@auth-vars-basic-wrong.yml" \
        --extra-vars cfg_dir=${HOME_DIR}/_cfg