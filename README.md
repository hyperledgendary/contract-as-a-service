# Running Hyperledger Fabric with K8S deployed Smart Contracts

*Aim* 

To show with Hyperledger Fabric and the latest IBM Blockchain Platform, how the Chaincode containers that run Smart Contracts can be run as deployments in K8S. These deployments can be in a namespace of your own choosing. This is made possible by the underlying Hyperledger Fabric Extenal Chaincode and Chaincode-as-a-server features.

*Main Objectives*

- When using IBP
  - Setup an Ansible based environment to use for configuration
  - Using the IBP Ansible collection, provision a basic network of Peers and Orderers
  - Provision the K8S resources needed to run the Docker image
  - Create the secrets needed to retrieve the image
  - Deployment of the actual chaincode
  - Using TLS between the peer and chaincode.
- For all environments
  - Be able to create Docker images for Java, Go and Node.js based Smart Contracts
  - Use simple applications to test the deployments
## Repo structure

**Smart Contracts**
There are 4 implementations of the same smart contract logic, Java, Go, JavaScript, and TypeScript.

- [Typescript](./typescript-contract/README.md)
- [Javascript](./node-contract/README.md)
- [Go](./go-contract/README.md)
- [Java](./java-contract/README.md)

**Infrastructure Setup**
For development purposes, using VSCode and Microfab is a great way to get started with development of the contract. This repo isn't designed to teach the details of development, but rather to show how you can work with the this type of chaincode

For production you can use the IBM Blockchain Platform, alternatively you can use the Hyperledger Fabric open source images.

- [IBM Blockhain Platform including K8S resources](./infrastructure/ansible-ibp/README.md)
- [Development with microfab](./infrastructure/dev-microfab/README.md)
- [Hyperledger Fabric](./infrastructure/docker-fabric/README.md)

**Client Applications**

- [Metadata Ping](./client-apps/metadata/README.md) Very simple 'ping' client app 
