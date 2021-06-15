## Smart Contract
The contract in this example is simple, but it's here just to demonstrate how it can be deployed. It's the basic getting started contract found in the Fabric Docs and the IBP VSCode exentions. The key thing is the dockerfile that is used to package up the contract, a new 'main' class and minor change to the build file.

### Chaincode-as-a-server
'Normally' the Peers will start (directly or indirectly in the case of things like IBP) the chaincode processes running. In this case, when the chaincode starts it 'calls back' to the peer to 'register'.

Here things are a bit different - the chaincode process becomes a server, and it's up to the peer to connect to it when needed to 'register'.

Once this initial 'registration' is complete, logically there's no difference between the two setups.

*Main Application* 

A very basic application needs to be added; the full source is a single file called [assetTransfer.go](./assetTransfer.go).
Most of this code is reading environment variables, and setting up basic configuration including handling the TLS files if needed

*Note* there are NO changes to the actual contract or libraries use; it's just this main file.

The TLS settings are refering to files that will mounted into the chaincode when this is deployed into K8S. The actual locations are arbitrary so you may alter them if you wish. 

### Dockerfile 

Firstly the dockerfile itself. This is a relatively simple node.js dockerfile, you've liberty here construct this as you wish. 

```docker
ARG GO_VER

FROM golang:1.14.15 as golang
ADD . /
WORKDIR /

FROM golang as peer
RUN go build -o /chaincode-server .

FROM registry.access.redhat.com/ubi8/ubi-minimal
COPY --from=peer /chaincode-server /usr/local/bin/chaincode-server

EXPOSE 9999
CMD ["/usr/local/bin/chaincode-server"]
```

Note the PORT is being set as 9999, and the command that is being run. So long as that command is run - and a port is setup that's the key thing. The port can be of your own choosing, 9999 is used here. 



Secondly you need to build and push this to a registry. The registry that I'm using is the container registry connected to the IBM K8S Cluster.
Ensure you've logged into the container registry (`ibmcloud cr login`) and push the docker image. If you don't have a namespace already create one, with for example  `ibmcloud cr namespace-add ibp_caas`


```bash 
just buildcontract go
```
This will build and then tag the image with `uk.icr.io/<my_namespace>/<my_repository>:<my_tag>` and push it for later use.
