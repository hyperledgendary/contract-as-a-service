# Running IBP with self-managed K8S Smart Contracts

*Aim* 

To show how with IBP 2.5.2, the Chaincode containers that run Smart Contracts can be run in a namespace of your own choosing in K8S. This is a new feature of IBP, and is made possible by the underlying Hyperledger Fabric - Extenal Chaincode and Chaincode-as-a-server features.

*Objectives*
- Setup an Ansible based environment to use for configuration
- Build a NodeJS Smart Contract in a Docker image & push the image to the repository
- Using the IBP Ansible collection, provision a basic network of Peers and Orderers
- Provision the K8S resources needed to run the Docker image
- Create the secrets needed to retrieve the image
- Deployment of the actual chaincode
- Testing it!

And using TLS between the peer and chaincode. [please note that this isn't yet working in this example]

## Setup

This tutorial will assume that you have installed IBP, with a free K8S Cluster created. The free cluser will last 28 days, but is perfectly sufficient for this. You can, of course, use another K8S environment if you have IBP installed there. 

### Suitable Python environment
Ansible is a main feature of this setup, and as Ansible is written in Python getting a Python environment is essential.  Experience has shown getting python setup can be time consuming and awkward. The easiest way that I've found to do this succesfully - and most importantly *repeatdly succesful* is using pipenv

I'll use this seqeuence of commands to get started here

```bash
pipenv --python 3.8
pipenv install fabric-sdk-py 
pipenv install 'openshift==0.11.2'
pipenv install jq
ansible-galaxy collection install ibm.blockchain_platform community.kubernetes ibmcloud.collection
# add --force to get upgrade to new versions of these collections
# note used to use moreati.jq but believed not to be required
```

Finally run `pipenv shell` to get into a shell that has the required python configuration.

### Login into IBM Cloud

If you don't have them already install the IBMCloud CLI, along with the plugins for the Container Registry and the Kubernetes Service

- [IBMCloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-getting-started)
- You should also install the Container Registry and Kubernetes Service [plugins](https://cloud.ibm.com/docs/cli?topic=cli-install-devtools-manually)

I would recommend logging in now to the cloud. If you go to the cluster overpage in the cloud, and click on "Actions..." and then "Connect via CLI" you will see a set of instructions. These will be something like this depending on the region your cluster is in.

```bash
ibmcloud login -a test.cloud.ibm.com -r us-south -g default
ibmcloud ks cluster config --cluster avaluewillbehere
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

Create a `.env` file that contains something like this.

```
# .env file 
CLOUD_API_KEY=a8aUjPRMrIgLhQXGWcl9tR_FxtdQvjQtmPXnKrFHQIK5
IBP_KEY=xxxxxxxxxxxxxxxxxxxx
IBP_ENDPOINT=https://xxxxxxxxxxxxxxxxxxxxxxxxx-ibpconsole-console.so01.blockchain.test.cloud.ibm.com
```

Then set these as environment variables - if you use the justfile these are automatically loaded.

```bash
export $(grep -v '^#' .env | xargs)
```

## QuickStart

All the commands below have been put into a justfile that can be run as follows

- `just nodecontract` builds and published the Docker image for the Node.js contract
- `just javacontract` builds and published the Docker image for the Java contract
- `just gocontract` builds and publised the Docker image for the Go contract (coming soon)
- `just network` builds the network of Peers, Orderers and CAs
- `just tls` creates the X509 certificates required to work with TLS between chaincode and peer
- `just iamsetup` creates the secret key to pull from the container registry 
- `just nodedeploy` Deploys the Node chaincode definition to the peer, and stands up the chaincode container in a separate k8s namespace from IBP
- `just javadeploy` Deploys the Java chaincode definition to the peer, and stands up the chaincode container in a separate k8s namespace from IBP
- `just identity` creates a application identity for client applications to use.

## Node.js Smart Contract
The contract in this example is simple, but it's here just to demonstrate how it can be deployed. It's the basic getting started contract found in the Fabric Docs and the IBP VSCode exentions. The key thing is the dockerfile that is used to package up the contract, and some minor changes to the package.json

### Chaincode-as-a-server
'Normally' the Peers will start (directly or indirectly in the case of things like IBP) the chaincode processes running. In this case, when the chaincode starts it 'calls back' to the peer to 'register'.

Here things are a bit different - the chaincode process becomes a server, and it's up to the peer to connect to it when needed to 'register'.

Once this initial 'registration' is complete, logically there's no difference between the two setups.

The key is to add this to the package.json scripts section.

```json
 "start:server": "fabric-chaincode-node server --chaincode-address=$CHAINCODE_SERVER_ADDRESS --chaincode-id=$CHAINCODE_ID --chaincode-tls-key-file=/hyperledger/privatekey.pem --chaincode-tls-client-cacert-file=/hyperledger/rootcert.pem --chaincode-tls-cert-file=/hyperledger/cert.pem"
```

I also like to add an `echo $CHAINCODE_SERVER_ADDRESS $CHAINCODE_ID && ` before the command `fabric-chaincode-node` command to get some debug.
*Note* there are NO changes to the actual contract or libraries used.. it's just this command in the `package.json`

The TLS settings are refering to files that will mounted into the chaincode when this is deployed into K8S. The actual locations are arbitrary so you may alter them if you wish. 

### Dockerfile 

Firstly the dockerfile itself. This is a relatively simple node.js dockerfile, you've liberty here construct this as you wish. 

```docker
FROM node:12.15-alpine

WORKDIR /usr/src/app

# Copy package.json first to check if an npm install is needed
COPY package.json /usr/src/app
RUN npm install --production

# Bundle app source
COPY . /usr/src/app

ENV PORT 9999
EXPOSE 9999

CMD ["npm", "run", "start:server"]
```

Note the PORT is being set as 9999, and the command that is being run. So long as that command is run - and a port is setup that's the key thing. The port can be of your own choosing, 9999 is used here.

Secondly you need to build and push this to a registry. The registry that I'm using is the container registry connected to the IBM K8S Cluster.
Ensure you've logged into the container registry (`ibmcloud cr login`) and push the docker image
```bash 
just contract node
just contract java

# or individal docker commands

docker build -t caasdemo-node .
docker tag caasdemo-node stg.icr.io/ibp_demo/caasdemo-node:latest
docker push  stg.icr.io/ibp_demo/caasdemo-node:latest
```

## Secret to pull the docker image

A K8S secret needs to be created with credentials of how to pull images from the Container Registry. Documentation is on line at, https://cloud.ibm.com/docs/containers?topic=containers-registry#other_registry_accounts of the sequence of commands that you need.

A Ansible playbook `ansible-playbooks/001-iam-id.yml` contains the required modules, bbut there's a defect in the IBM Terraform that's stopping this working at present (https://github.com/IBM-Cloud/terraform-provider-ibm/issues/2377). So do this via the cli commands in the above documentation link. They are summarised at the top of the playbook as well. 

## IBP Configuration

We need to create the Peers/Orderers and CAs etc. The `ansible-playbooks/000-create-network.yml` will create this for us. 

As IBP Playbooks are concerned this is very standard, so I won't go into detail of how this works.

```bash
just network
# or
ansible-playbook ./ansible-playbooks/000-create-network.yml \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars channel_name=${CHANNEL_NAME} \
    --extra-vars home_dir=${DIR} 
```

Then we need to setup the chaincode; this is where some of the 'magic' happens, so we'll go through it in more detail.

### Deploy chaincode playbook details

This is the `001-setup-k8s-chaincode.yml` playbook.

```bash
just deploy node
just deploy java

# alternatively chainging the contract name as needed

ansible-playbook ./ansible-playbooks/001-setup-k8s-chaincode.yml \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars channel_name=${CHANNEL_NAME} \
    --extra-vars smart_contract_name=nodecontract \
    --extra-vars smart_contract_version=2 \
    --extra-vars smart_contract_sequence=2 \
    --extra-vars home_dir=${DIR} \
```


1. K8S namespace. First thing is to create a namespace separate from the running IBP instance.

```yaml
    - name: Setup the namepsace
      community.kubernetes.k8s:
        name: caasdemo
        api_version: v1
        kind: Namespace
        state: present
```

2. Service instance. A key thing is the peer being able to locate the chaincode, and connect. This is done via a Service and using a ClusterIP type service. The port here is the same as mentioned above, and be changed if you wish. 

```yaml
    - name: Create a Service object from an inline definition
      community.kubernetes.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Service
          metadata:
            namespace: caasdemo
            name: nodecc
            labels:
              app: caasdemo
          spec:
            ports:
            - name: chaincode
              port: 9999
              targetPort: 9999
              protocol: TCP
            selector:
              app: caasdemo
      register: result
```

3. 'Proxy' Chaincode. You need to install a 'proxy' chaincode to indicate where the chaincode is actually running. The 'code' is a json file `connection.json`. The following two steps create this file and package it up as an 'external chaincode'

```yaml
    - copy:
        content: "{{ result.result.spec | moreati.jq.jq('{address: \"nodecc.caasdemo:9999\",dial_timeout:\"10s\",tls_required:false}') }}"
        dest: ./connection.json
    - name: Create the archive
      command: ../pkgcc.sh -l nodecontract -t external connection.json
```

4. Install, Approve and Commit. The chaincode needs to be installed, approved and committed. This is a standard use of the ansible tasks. They can be used sequentially here, but in a multi organizational environment would need to be handled differently.

5. Chaincode Configuration. The actual running chaincode needs to know it's 'name' this is assigned by the peer in the previous install step. We can capture that in ansible and put it into a Config Map. 

*Note* this is Node chaincode, so the `CHAINCODE_SERVER_ADDRESS` is `0.0.0.0` again with the port 9999.  

```yaml
    - name: Create a ConfigMap for the chaincode configuration
      community.kubernetes.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: nodecc.v5.conf
            namespace: caasdemo
            labels:
              app:  caasdemo
          data:
            CHAINCODE_SERVER_ADDRESS: 0.0.0.0:9999
            CHAINCODE_ID: "{{ installcc_result.installed_chaincode.package_id }}"
```

6. Deploy the Chaincode. Finally we can deploy the chaincode and get it running. 

```yaml
    - name: Create a ConfigMap for the chaincode configuration
      community.kubernetes.k8s:
        state: present
        definition:
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            namespace: caasdemo
            name: caasdemo
            labels:
              app: caasdemo
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: caasdemo
            template:
              metadata:
                labels:
                  app: caasdemo
              spec:
                containers:
                  - name: nodecc
                    image: stg.icr.io/ibp_demo/caasdemo-node          
                    resources:
                      requests:
                        memory: "50Mi"
                        cpu: "0.1"
                    ports:
                    - containerPort: 9999
                    envFrom:
                      - configMapRef:
                          name: nodecc.v5.conf
                imagePullSecrets:
                  - name: pullimg-secret
```

This final deployment is tying a few things together.

- The Docker image name of the container, and the secret used to pull this from the registry
- Again we can see the port in use
- The config map being used to configure the environment.

## Checkpoint!

We've achieved the following:

- Created and built a Nodejs (or Java or Go) Smart Contract, and produced a Docker image to host it (the chaincode).
- This has been pushed to the docker registry, and we've created a secret to be used to pull the image
- Using Ansible, we've created the IBP network, and installed a proxy chaincode
- K8S resources of the config maps, the service and deployment have been created

Next steps are to create an indentity, and use that to submit transactions

## Create identities

There's a Ansible playbook `002-create-identity.yml` that will create an identity, and make it available for use with Client side applications.

```bash
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
```

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

