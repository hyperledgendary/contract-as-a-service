#!/bin/bash
set -evx -o pipefail

DIR="$(realpath $(dirname "$0"))/.."

ansible-playbook ./config/ansible-playbooks/001-setup-k8s-chaincode.yml \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars channel_name=${CHANNEL_NAME} \
    --extra-vars smart_contract_name=nodecontract \
    --extra-vars smart_contract_version=2 \
    --extra-vars smart_contract_sequence=2 \
    --extra-vars home_dir=${DIR}/_cfg \

