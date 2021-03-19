#!/bin/bash

DEFAULTLOCN=~/.local/fabric
LOCN=$(realpath ${1:-$DEFAULTLOCN})

mkdir -p ${LOCN} 
curl -sSL https://github.com/hyperledger/fabric/releases/download/v2.3.1/hyperledger-fabric-linux-amd64-2.3.1.tar.gz | tar xzf - -C ${LOCN}  
curl -sSL https://github.com/hyperledger/fabric-ca/releases/download/v1.5.0/hyperledger-fabric-ca-linux-amd64-1.5.0.tar.gz | tar xzf - -C ${LOCN}

echo "export FABRIC_CFG_PATH=${LOCN}/config"
echo "export PATH=${LOCN}/bin:\${PATH}"
