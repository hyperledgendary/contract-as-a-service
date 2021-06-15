## Smart Contract
The contract in this example is simple, but it's here just to demonstrate how it can be deployed. It's the basic getting started contract found in the Fabric Docs and the IBP VSCode exentions. The key thing is the dockerfile that is used to package up the contract, and some minor changes to the package.json

### Chaincode-as-a-server
'Normally' the Peers will start (directly or indirectly in the case of things like IBP) the chaincode processes running. In this case, when the chaincode starts it 'calls back' to the peer to 'register'.

Here things are a bit different - the chaincode process becomes a server, and it's up to the peer to connect to it when needed to 'register'.

Once this initial 'registration' is complete, logically there's no difference between the two setups.

The key is to add this to the package.json scripts section.

```json
 "start:server": "fabric-chaincode-node server --chaincode-address=$CHAINCODE_SERVER_ADDRESS --chaincode-id=$CHAINCODE_ID --chaincode-tls-key-file=/hyperledger/privatekey.pem --chaincode-tls-client-cacert-file=/hyperledger/rootcert.pem --chaincode-tls-cert-file=/hyperledger/cert.pem"
```

*Note* there are NO changes to the actual contract or libraries used.. it's just this command in the `package.json` along with the Docker-ization parts.

The TLS settings are refering to files that will mounted into the chaincode when this is deployed into K8S. The actual locations are arbitrary so you may alter them if you wish. In the package.json there is also the non-TLS command

### Dockerfile 

Firstly the dockerfile itself. This is a relatively simple node.js dockerfile, you've liberty here construct this as you wish. 

```docker
FROM node:12.15

WORKDIR /usr/src/app

# Copy package.json first to check if an npm install is needed
COPY package.json /usr/src/app
RUN npm install --production

# Bundle app source
COPY . /usr/src/app

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

COPY docker/docker-entrypoint.sh /usr/src/app/docker-entrypoint.sh

ENV PORT 9999
EXPOSE 9999

ENTRYPOINT [ "/tini", "--", "/usr/src/app/docker-entrypoint.sh" ]
```

Note the PORT is being set as 9999, and the command that is being run. So long as that command is run - and a port is setup that's the key thing. The port can be of your own choosing, 9999 is used here. The `docker-entrypoint.sh` script is there to swap between TLS and non-TLS

```bash
if [ "${CORE_PEER_TLS_ENABLED,,}"  = "true" ]; then
    npm run start:server
else
    npm run start:server-nontls
fi
```

Secondly you need to build and push this to a registry. The registry that I'm using is the container registry connected to the IBM K8S Cluster.
Ensure you've logged into the container registry (`ibmcloud cr login`) and push the docker image. If you don't have a namespace already create one, with for example  `ibmcloud cr namespace-add ibp_caas`


```bash 
just buildcontract node
```
This will build and then tag the image with `uk.icr.io/<my_namespace>/<my_repository>:<my_tag>` and push it for later use.
