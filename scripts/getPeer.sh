#!/bin/bash

LOCN=~/.local/fabric

mkdir -p ${LOCN} 
curl -sSL https://github.com/hyperledger/fabric/releases/download/v2.2.1/hyperledger-fabric-linux-amd64-2.2.1.tar.gz | tar xzf - -C ${LOCN}  
curl -sSL https://github.com/hyperledger/fabric-ca/releases/download/v1.4.9/hyperledger-fabric-ca-linux-amd64-1.4.9.tar.gz | tar xzf - -C ${LOCN}

echo "export FABRIC_CFG_PATH=${LOCN}/config"
echo "export PATH=${LOCN}/bin:\${PATH}"
