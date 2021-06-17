# Contract Development

The best way to develop the contract initially is by using VSCode and the IBP Extension. 

## VSCode

You can of course, use the editor you wish, but the VSCode extension makes it a lot easier. Install the extension from the [VSCode MarketPlace](https://marketplace.visualstudio.com/items?itemName=IBMBlockchain.ibm-blockchain-platform)

If you've never written a Smart Contract before or never used the extension please follow the basic tutorials from the extenion's welcome screen. 

## Develop the code

Using the tools in VSCode as covered in the tutorials, you can write a contract. This repo already has the contracts written and ready to go. For working with external contracts as a service, I like to use Microfab running outside of VSCode. It's easier to follow what is occuring.

## Run Microfab and build the Contract Image

1. Setup the configuration for Microfab. This is using a single organization

```bash
export MICROFAB_CONFIG='{
    "endorsing_organizations":[
        {
            "name": "DigiBank"
        }
    ],
    "channels":[
        {
            "name": "assetnet",
            "endorsing_organizations":[
                "DigiBank"
            ]
        }
    ],
    "capability_level":"V2_0"
}'
```

2. Start Microfab

Create a docker network to run both Microfab and the Chaincode Server on
```bash
docker network create cc_network
```

```bash
docker run --name microfab  --network cc_network --rm -ti -p 8080:8080 -e MICROFAB_CONFIG="${MICROFAB_CONFIG}"  ibmcom/ibp-microfab
```

This is best run in it's own console window.

If you wish at this point you can connect to this from VSCode, go to the 'Fabric Environments' and click on the plus. Select 'Add a Microfab Network'. The default address should be good.

3. Build the docker image for the chaincode

It's best to build a docker image for chaincode to run. Each contract has a dockerfile within it suitable for the langauge. 

A simple `docker build -t caasdemo-{{LANG}} ./{{LANG}}-contract/` changing the name of the langauge to match the directory. The name and location is not critical so please adopt your own conventions.


### Get the MicroFab configuration

When applications (including the Peer commands ) run they need a local identity in a wallet and a gateway connection profile. In this case there's a helpful script that can pull out all the information needed. 

Run this in your working directory - some sub-directories will be created. 

```bash
npm install -g @hyperledgendary/weftility
curl -s http://console.127-0-0-1.nip.io:8080/ak/api/v1/components | weft microfab -w ./_cfg/microfab/_wallets -p ./_cfg/microfab/_gateways -m ./_cfg/microfab/_msp -f
```

Then setup some environment variables for the peer commands; these are output by the command above, but should be something similar to the following. Remember to NOT use the settings for the CA - as we need to talk to the peer.

```bash
export CORE_PEER_LOCALMSPID=DigiBankMSP
export CORE_PEER_MSPCONFIGPATH=/home/matthew/github.com/hyperledgendary/contract-as-a-server/infrastructure/microfab-dev/_msp/DigiBank/digibankadmin/msp
export CORE_PEER_ADDRESS=digibankpeer-api.127-0-0-1.nip.io:8080```
```

## Contract Deploy

### Package Proxy Chaincode

Create a `connection.json` file with details of how Fabric will connect to the external service chaincode

```
{
  "address": "cc.example.com:9999",
  "dial_timeout": "10s",
  "tls_required": false
}
```

Package the `connection.json` file using the [pkgcc.sh](https://github.com/hyperledgendary/fabric-builders/blob/master/tools/pkgcc.sh) script

Again if you have the same directory structure, this command

```bash
./scripts/pkgcc.sh -l extcc -t external connection.json
```

A `extcc.tgz` file will be created. This is the chaincode package that will be installed on the peer - as the proxy for the real chaincode.  Feel free to unpack and investigate it's contents.  Note that this is the equiavlent of doing a `peer lifecycle chaincode package`

### Install the Proxy Chaincode

Install this proxy chaincode package.

```
peer lifecycle chaincode install extcc.tgz
```

It's important to keep the output from this command as it will be needed in the next step

### Run External chaincode

Create a `chaincode.env` file, making sure the CHAINCODE_ID matches the chaincode code package identifier from the install command. (the one in the tests/assets directory should be sufficient if you've also copied the wasmftw.tgz file.  Just double check the package id matches)

```
CHAINCODE_SERVER_ADDRESS=cc.example.com:9999
CHAINCODE_ID=extcc:36b16a0a18c72deb79ca727313f4fe32fe9fd73917aa8d119bcd42ba08fc7675
```

Run the chaincode: note that this docker command runs it in foreground so you can watch what happens.  Worth opening another terminal at this point to run this in docker command in.

```
docker run -it --rm --name cc.example.com --hostname cc.example.com --env-file chaincode.env --network=cc_network caasdemo-node
```

**Note we're matching the hostname here with the hostname in the connection.json. Also it's running on the same docker network as MicroFab. So long as these conditions are met the naming can be altered as you wish**

### Approve and commit the proxy chaincode

Approve the chaincode, making sure the `package-id` matches the chaincode code package identifier from the install command

```
peer lifecycle chaincode approveformyorg -o orderer-api.127-0-0-1.nip.io:8080 --channelID assetnet --name extcc --version 1 --sequence 1 --waitForEvent --package-id extcc:36b16a0a18c72deb79ca727313f4fe32fe9fd73917aa8d119bcd42ba08fc7675
```

Commit the chaincode

```
peer lifecycle chaincode commit -o orderer-api.127-0-0-1.nip.io:8080 --channelID assetnet --name extcc --version 1 --sequence 1
```

## Run a transaction!

Simples transaction to run is this `GetMetadata` function - it returns a JSON description of the chaincode.. it's been piped to jq for easy of reading.

```bash
peer chaincode query -o orderer-api.127-0-0-1.nip.io:8080 --channelID assetnet -n extcc -c '{"function":"org.hyperledger.fabric:GetMetadata","Args":[]}' | jq
```