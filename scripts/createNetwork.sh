#!/bin/bash
set -evx -o pipefail

DIR="$(realpath $(dirname "$0"))/.."
mkdir -p ${DIR}/_cfg

ansible-playbook ./ansible-playbooks/000-create-network.yml \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars home_dir=${DIR}/_cfg 
