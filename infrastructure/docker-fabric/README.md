# Hyperledger Fabric

This section will show how to setup and use the chaincode-as-a-service with the test-network within the fabric-samples repo.

## Getting the code setup

1) You should follow the instructions to get the fabric-samples repo, Fabric binaries and docker containers. Full docs are [here](https://hyperledger-fabric.readthedocs.io/en/latest/install.html) but essentiall this is the install script.

```bash
curl -sSL https://bit.ly/2ysbOFE | bash -s
```

We'll be modifying the test-network docker-compose slightly, so you might wish to create a new branch or take a backup.

2) Clone this repo :-)

3) IBP & MicroFab already has external chaincode as as service builders installed, the 'vanilla' Fabric images don't. The documentation includes bash scripts for these, however as the fabric images are built with alpine as the base image, bash isn't installed. 

However there are some simple golang equivlents we can use, these are in the following repo, and can be simply built with go

```
git clone https://github.com/hyperledgendary/fabric-ccs-builder.git
cd fabric-css-builder

go build -o bin ./cmd/build/
go build -o bin ./cmd/detect/
go build -o bin ./cmd/release/
```

I'd suggest that you copy the built binaries to your fabric-samples directory. Assuming that the fabric-samples repo is alongside the fabric-ccs-builder directory.

```bash
 cp -r ./bin ../fabric-samples/external-chaincode/builder/

# the structure of the filesystem should be like this
fabric-samples
├──external-chaincode
    ├── builder
        └── bin
            ├── build
            ├── detect
            └── release
```
## Configuring the test-network

1) We need to create an updated `core.yaml` file. It's best to copy the current `core.yaml` for the docker images you've locally. 

```bash
cd fabric-samples/external-chaincode
docker cp $(docker create --rm hyperledger/fabric-peer:latest):/etc/hyperledger/fabric/core.yaml ./core.yaml
```

Load this into an editor and find the `externalBuilders: []` section and replace it with this.

```yaml
    externalBuilders: 
        - path: /etc/hyperledger/fabric/external-chaincode/builder
          name: external-service-builder
          propagateEnvironment:
            - HOME
            - CORE_PEER_ID
            - CORE_PEER_LOCALMSPID
```

This configures the external builders.

2) We need to update docker-compose file that starts the containers to ensure the the buliders are mounted, and the new `core.yaml` is picked up.

Location the `docker-comnpose-test-net.yaml` file in `fabric-samples/test-network/docker` For BOTH peers, add the following volume mounts

```
        - ../../external-chaincode:/etc/hyperledger/fabric/external-chaincode
        - ../../external-chaincode/core.yaml:/etc/hyperledger/fabric/core.yaml
```

## Start the test network

With the builders built, the core.yaml updated, and the docker-compose with additional volume mounts, the test-network can be started. This is no different, and all the standard examples etc will still work. 

The difference here is that there is an external builder that can be used.  

... from here follow the same notes in the [development](../dev-microfab/README.md) section about running the chaincode in a docker container. 
Note that test-network is on the `fabric-test` docker network.