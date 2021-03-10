#!/bin/bash
set -evx -o pipefail

CHANNEL_NAME=caaschannel
DIR="$(realpath $(dirname "$0"))"
echo $DIR

ansible-playbook ./config/ansible-playbooks/000-create-network.yml \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars channel_name=${CHANNEL_NAME} \
    --extra-vars home_dir=${DIR} \

ansible-playbook ./config/ansible-playbooks/001-setup-k8s-chaincode.yml \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars channel_name=${CHANNEL_NAME} \
    --extra-vars smart_contract_name=nodecontract \
    --extra-vars smart_contract_version=2 \
    --extra-vars smart_contract_sequence=2 \
    --extra-vars home_dir=${DIR} \

ansible-playbook ./config/ansible-playbooks/002-create-identity.yml \
    --extra-vars id_name="fred" \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars channel_name=${CHANNEL_NAME} \
    --extra-vars home_dir=${DIR} \
    --extra-vars network_name=CAASDEMO \
    --extra-vars org1_name=CAASOrg1 \
    --extra-vars org1_msp_id=CAASOrg1MSP

runhfsc --gateway ./_cfg/ansible/_gateways/CAASDEMO_CAASOrg1.json --wallet ./_cfg/ansible/_wallets/CAASDEMO_CAASOrg1 --user fred --channel caaschannel