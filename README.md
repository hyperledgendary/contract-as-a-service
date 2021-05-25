# Running IBP with self-managed K8S Smart Contracts

*Aim* 

To show how with IBP 2.5.2, the Chaincode containers that run Smart Contracts can be run in a namespace of your own choosing in K8S. This is a new feature of IBP, and is made possible by the underlying Hyperledger Fabric Extenal Chaincode and Chaincode-as-a-server features.

*Objectives*
- Setup an Ansible based environment to use for configuration
- Build a NodeJS Smart Contract in a Docker image & push the image to an image repository
- Using the IBP Ansible collection, provision a basic network of Peers and Orderers
- Provision the K8S resources needed to run the Docker image
- Create the secrets needed to retrieve the image
- Deployment of the actual chaincode
- Testing it!
- And using TLS between the peer and chaincode.

## Setup

This tutorial will assume that you have an installed IBP, hosted within an IKS cluster. The same approach should be applicable to other K8S instances.

### Suitable Python environment
Ansible is a main feature of this setup, and as Ansible is written in Python getting a Python environment is essential.  Experience has shown getting python setup can be time consuming and awkward. The easiest way that I've found to do this succesfully - and most importantly *repeatdly succesful* is using [pipenv](https://pipenv.pypa.io/en/latest/)

I'll use this seqeuence of commands to get started here

```bash
pipenv --python 3.8
pipenv install fabric-sdk-py 
pipenv install 'openshift==0.11.2'   
ansible-galaxy collection install ibm.blockchain_platform community.kubernetes ibmcloud.collection
# add --force to get upgrade to new versions of these collections
```

The ibm.blockchain-platform collection can also target OpenShift environments, which is why that is listed. 
Finally run `pipenv shell` to get into a shell that has the required python configuration.

### Login into IBM Cloud

If you don't have them already install the IBMCloud CLI, along with the plugins for the Container Registry and the Kubernetes Service

- [IBMCloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-getting-started)
- You should also install the Container Registry and Kubernetes Service [plugins](https://cloud.ibm.com/docs/cli?topic=cli-install-devtools-manually)

I would recommend logging in now to the cloud. If you go to the cluster overpage in the cloud, and click on "Actions..." and then "Connect via CLI" you will see a set of instructions. These will be something like this depending on the region your cluster is in.

```bash
ibmcloud login -a test.cloud.ibm.com -r us-south -g default
ibmcloud ks cluster config --cluster <avaluewillbehere>
ibmcloud cr login
```

You'll be able to use the `kubectl` command now, and the K8S Ansible tasks later will also work without needing a separate API key.

### Additional tools

- Nodejs (version 12+). Suggested you use `nvm` for this
- To make it easy to run the `ansible-playbook` commands, they have been put into a justfile - download [just here](https://github.com/casey/just#pre-built-binaries). Very similar syntax to make, but just files will automatically read the `.env` file for api keys, and doesn't echo these to the console. If you don't wish to use this, `cat justfile` and copy the playbook commands.
- Docker for building the containers
- There are a couple of NodeJS utilities needed (will install those as needed below)

### Hyperledger Fabric Peer Commands
You'll need to have a copy of the Fabric Peer Commands. To help there's a script `getPeer.sh` that can get them for you.

```bash
./scripts/getPeer.sh
```

This will output the environment variables you should set to ensure the tools are the path, and the `FABRIC_CFG_PATH` is set. Check the install is correct by checking the version of the peer.

```bash
peer version

# output. need to have 2.2.1 or later
peer:
 Version: 2.2.1
 Commit SHA: 344fda602
 Go version: go1.14.4
 OS/Arch: linux/amd64
 Chaincode:
  Base Docker Label: org.hyperledger.fabric
  Docker Namespace: hyperledger
```

### API Keys
There are 2 API keys you need:

- IBP Console service credentials.  These can be [created from the web ui](https://cloud.ibm.com/docs/account?topic=account-service_credentials)
- IBM Cloud API key. Create a [User API Key](https://cloud.ibm.com/docs/account?topic=account-userapikey#manage-user-keys)

Create a `auth-vars-ibp.yml` file that contains something like this.
```
api_key: <apikey>
api_endpoint: https://<ibp_console>
api_authtype: basic
api_secret: <secret>
```

And for `auth-vars-cloud.yml`
```
cloud_api_key=<api key>
```

Note that this is only used for the script to create the secret needed to pull from the image registry

## QuickStart

All the commands below have been put into a justfile with the following 'recipes'

```
just --list
Available recipes:
    buildcontract LANG # Currently set to push to IBM staging
    clean              # removes the _cfg directory where wallets, connection profiles etc are stored.
    deploycaas LANG    # Note the contract version and sequence
    deploymanaged LANG # This the managed way of deploying chaincode
    iamsetup           # means it's best to do this by hand with the CLI. (it's a one time setup)
    network            # This builds the Fabric Network - Peers, CAs, Orderers and creates the admin identities
    ping LANG          # Ping the contract working as DigiBank
    registerapp        # This creates an application identity that can be used to interact via client applications
    tls LANG           # For TLS, configure new Certificates approved by the Org1 CA.
```
## Smart Contract
The contract in this example is simple, but it's here just to demonstrate how it can be deployed. It's the basic getting started contract found in the Fabric Docs and the IBP VSCode exentions. The key thing is the dockerfile that is used to package up the contract, and some minor changes to the package.json

NOTE: There are other languages in this repo, but to-date they are not yet tested. Only the NodeJS one is good to go.

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


## Secret to pull the docker image

A K8S secret needs to be created with credentials of how to pull images from the Container Registry. Documentation is on line at, https://cloud.ibm.com/docs/containers?topic=containers-registry#other_registry_accounts of the sequence of commands that you need.

A Ansible playbook `ansible-playbooks/001-iam-id.yml` contains the required modules, but there's a defect in the IBM Terraform that's stopping this working at present (https://github.com/IBM-Cloud/terraform-provider-ibm/issues/2377). So do this via the cli commands in the above documentation link. They are summarised at the top of the playbook as well. 

This is a one time only setup.

[Note need to check if this is has been fixed]

## IBP Configuration

We need to create the Peers/Orderers and CAs etc. As IBP Playbooks are concerned this is very standard, so I won't go into detail of how this works. It's using the same playbooks as in the Ansible Tutorial, but with a configuration to create 2 peers for the ogranization. 

```bash
just network
```

Then we need to setup the chaincode; this is where some of the 'magic' happens, so we'll go through it in more detail.

### Deploy chaincode playbooks
There are three playbooks here, separated for practical convience - you may order these as you wish. 

**First**, is the `002-k8s-cc-tls-setup.yml` playbook. This creates an 'indentity' with the organzaitions CA and the certificates of that are then used for TLS.

`just tls node` will create two indenties, one to for the chaincode, and one for th epeer. 

Note - should modify this to get an indentity for each chaincode - the `connection.json` only needs to know the CA of the chaincode certificates.

**Second**, is the `002-setup-k8s-chaincode.yml`. This playbook will create the K8S services for each peers own chaincode, and also create the `connection.json` that then packaged as a regular chaincode archive.

**Third**, is tje `003-start-k8s-chaincode.yml`. This playbook will install the chaincode on each peer and then approve the chaincode. It then commits this.

Two ConfigMaps are created, one for the TLS Cert keys, the second for regular Chaincode Configuration. Each is named according to this basic scheme `{{ smart_contract_name }}.v{{ smart_contract_sequence }}.conf"` - this is to ensure then when a new chaincode sequence number is used, a new config map name is used. This will ensure the chaincode pod will be updated.

Two deployments are used to stand up the chaincode, each for use by a different peer. 
## Checkpoint!

We've achieved the following:

- Created and built a Nodejs (or Java or Go) Smart Contract, and produced a Docker image to host it (the chaincode).
- This has been pushed to the docker registry, and we've created a secret to be used to pull the image
- Using Ansible, we've created the IBP network, and installed a proxy chaincode
- K8S resources of the config maps, the service and deployment have been created

Next steps are to create an indentity, and use that to submit transactions

**Note sections below still need updating**

## Create identities

The first half of this playbook is using the IBP collection to create the identity. The second half is using a community utility to take the identities from IBP and create a local wallet for use by the Fabric Client SDKs.

(If you've not installed this already, `npm install -g @hyperledgendary/weftility`)

The `_cfg` directory will be created that contains a connection profile, and a couple of wallets to use with the 'fred' identity.  

## Using these identities

Next and final step is to actually send some transactions.  You could at this point write your own client app, or use the VSCode extension, or use an already written client side app.  

Let's do the last of those, install `runhfsc`

```
npm install -g @hyperledgednary/runhfsc
runhfsc --gateway ./_cfg/ansible/_gateways/CAASDEMO_CAASOrg1.json --wallet ./_cfg/ansible/_wallets/CAASDEMO_CAASOrg1 --user fred --channel caaschannel
```

You'll now get a command prompt, if you type `contract nodecontract` here that will connect to IBP.

Then if you type `metadata` it will issue a transaction to query the metadata of the contract (if this works you know you've got full end-end connectivity)

```
 contract nodecontract
Contract set to nodecontract
[default] fred@caaschannel:nodecontract - $ metadata
(node:22057) [DEP0123] DeprecationWarning: Setting the TLS ServerName to an IP address is not permitted by RFC 6066. This will be ignored in a future versi
on.
> {
  '$schema': 'https://hyperledger.github.io/fabric-chaincode-node/release-2.1/api/contract-schema.json',
  contracts: {
    MyAssetContract: {
      name: 'MyAssetContract',
      contractInstance: { name: 'MyAssetContract', default: true },
      .....
      .....
```


This is a simple asset creation example, so lets create an asset
```
submit createMyAsset '["007","Bond James Bond"]'
{
  txname: 'createMyAsset',
  args: '["007","Bond James Bond"]',
  private: undefined
}
Submitted createMyAsset  007,Bond James Bond
>
````

And to read the asset backagain

```
evaluate readMyAsset '["007"]'
Submitted readMyAsset  007
> {"value":"Bond James Bond"}
```

Reading an asset that doesn't exist (or maybe you just don't have clearence to know about?)
```
 evaluate readMyAsset '["004"]'
Submitted readMyAsset  004
Error: error in simulation: transaction returned with failure: Error: The my asset 004 does not exist
```

