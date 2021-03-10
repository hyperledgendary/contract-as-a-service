# Running IBP with self-managed K8S Smart Contracts

Aim of this is to show how with IBP 2.5.2, the Chaincode containers that run Smart Contracts can be run in a namespace of your own choosing in K8S. This is a new feature of IBP, and is made possible by the underlying Hyperledger Fabric - Extenal Chaincode and Chaincode-as-a-server features.

Objectives
- Setup an Ansible based environment to use for configuration
- Build a NodeJS Smart Contract in a Docker image & push the image to the repository
- Using the IBP Ansible collection, provision a basic network of Peers and Orderers
- Provision the K8S resources needed to run the Docker image
- Create the secrets needed to retrieve the image
- Deployment of the actual chaincode
- Testing it!

## Prereqs

Access to IBP, and an IBM Console instance created - this can all be done in the free cluster option. Will last 28 days, but is perfectly sufficient for this.

### Suitable Python environment

Ansible is written in Python; and getting python setup can be time consuming and awkward. The easiest way that I've found to do this succesfully - and most importantly *repeatdly succesful* is using pipenv

I'll use this seqeuence of commands to get started here

```bash
pipenv --python 3.8
pipenv install fabric-sdk-py 
pipenv install 'openshift==0.11.2'
pipenv install jq

ansible-galaxy collection install ibm.blockchain_platform community.kubernetes moreati.jq
# add --force to get upgrade to new versions of these collections
```

Finally run `pipenv shell` to get into a shell that has the required python configuration.

### Additional tools

- Nodejs (version 12+) 
- ibmcloud cli, with cr plugins, and kubectl can be useful but not essential
- Docker for building the container
- There are a couple of NodeJS utilities needed (....)


## API Keys
Will need service credentials for the IBP Console

```
# .env file 

```

```bash
export $(grep -v '^#' .env | xargs)
```

## Node.js Smart Contract

The contract in this example is simple, but it's here just to demonstrate how it can be deployed. It's the basic getting started contract found in the Fabric Docs and the IBP VSCode exentions.

The key thing is the dockerfile that is also part of the contract, and some minor changes to the package.json

### Chaincode-as-a-server
'Normally' the Peers will start (directly or indirectly in the case of things like IBP) the chaincode processes running. In this case, when the chaincode starts it 'calls back' to the peer to 'register'.

Here things are a bit different - the chaincode process becomes a server, and it's up to the peer to connect to it when needed to 'register'.

Once this initial 'registration' is complete, logically there's no difference between the two setups.

The key is to add this to the package.json scripts section.

```
 "start:server": "fabric-chaincode-node server --chaincode-address=$CHAINCODE_SERVER_ADDRESS --chaincode-id=$CHAINCODE_ID"
```

I also like to add an `echo $CHAINCODE_SERVER_ADDRESS $CHAINCODE_ID && ` before the command `fabric-chaincode-node` command to get some debug.

*Note* there are NO changes to the actual contract or libraries used.. it's just this command in the `package.json`

### Dockerfile 

Firstly the dockerfile itself. This is a relatively simple node.js dockerfile, you've liberty here construct this as you wish. 

```
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

Secondly you need to build and push this to a registry. The registry that is being used in the container registry connected to the IBM K8S Cluster.

```
docker build -t caasdemo-node .
docker tag caasdemo-node stg.icr.io/ibp_demo/caasdemo-node:latest
```


```
ibmcloud cr login
docker push  stg.icr.io/ibp_demo/caasdemo-node:latest
```

## Secret to pull the docker image

Documentation is on line at, 
https://cloud.ibm.com/docs/containers?topic=containers-registry#other_registry_accounts


The requried commands are in the `createIAMSecret.sh` script. This only needs to be run once.

## IBP Configuration

The IBP Ansible collection is being used here - firstly the playbook to create the Peers/Orderes etc needs to be run.

As IBP Playbooks are concerned this is very standard, so I won't go into detail of how this works.
```
ansible-playbook ./config/ansible-playbooks/000-create-network.yml \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars channel_name=${CHANNEL_NAME} \
    --extra-vars home_dir=${DIR} 
```

Then we need to setup the chaincode - this is different to usual so wil

```
ansible-playbook ./config/ansible-playbooks/001-setup-k8s-chaincode.yml \
    --extra-vars api_key=${IBP_KEY} \
    --extra-vars api_endpoint=${IBP_ENDPOINT} \
    --extra-vars api_token_endpoint=${API_TOKEN_ENDPOINT} \
    --extra-vars channel_name=${CHANNEL_NAME} \
    --extra-vars smart_contract_name=nodecontract \
    --extra-vars smart_contract_version=2 \
    --extra-vars smart_contract_sequence=2 \
    --extra-vars home_dir=${DIR} \
```

### Playbook details

This is the `001-setup-k8s-chaincode.yml` playbook.

K8S namespace. First thing is to create a namespace separate from the running IBP instance.

```yaml
    - name: Setup the namepsace
      community.kubernetes.k8s:
        name: caasdemo
        api_version: v1
        kind: Namespace
        state: present
```

Service instance. A key thing is the peer being able to locate the chaincode, and connect. This is done via a Service and using a ClusterIP type service. The port here is the same as mentioned above, and be changed if you wish. 

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

'Proxy' Chaincode. You need to install a 'proxy' chaincode to indicate where the chaincode is actually running. The 'code' is a json file `connection.json`. The following two steps create this file and package it up as an 'external chaincode'

```yaml
    - copy:
        content: "{{ result.result.spec | moreati.jq.jq('{address: \"nodecc.caasdemo:9999\",dial_timeout:\"10s\",tls_required:false}') }}"
        dest: ./connection.json
    - name: Create the archive
      command: ../pkgcc.sh -l nodecontract -t external connection.json
```

Install, Approve and Commit. The chaincode needs to be installed, approved and committed. This is a standard use of the ansible tasks. They can be used sequentially here, but in a multi organizational environment would need to be handled differently.

Chaincode Configuration. The actual running chaincode needs to know it's 'name' this is assigned by the peer in the previous install step. We can capture that in ansible and put it into a Config Map. 

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

Deploy the Chaincode. Finally we can deploy the chaincode and get it running. 

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

This is tying a few things together.

- The Docker image name of the container, and the secret used to pull this from the registry
- Again we can see the port in use
- The config map being used to configure the environment.

## Checkpoint!

We've achieved the following:

- Created and built a Nodejs Smart Contract, and produced a Docker image to host it (the chaincode).
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

