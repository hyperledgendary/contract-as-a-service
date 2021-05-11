// Apache-2
const fs = require('fs')
const path = require('path')
const chalk = require('chalk')
const JSON_EXT = /json/gi;
const YAML_EXT = /ya?ml/gi;

const prettyjson = require("prettyjson-256");
// Credentials that are required
prettyjson.init({alphabetizeKeys:true});

const { Wallets, Gateway } = require('fabric-network');

const env = require('env-var');
const wallet_dir = env.get("WALLET_DIR").required().asString();
const id_name = env.get("ID_NAME").required().asString();
const gateway_profile = env.get("GATEWAY_PROFILE").required().asString();
const contract_name = env.get("CONTRACT").required().asString();
const channel = env.get("CHANNEL").required().asString();

const CP = path.resolve(gateway_profile);
const WP = path.resolve(wallet_dir);

console.log(chalk.blue("Gateway Connection Profile: ")+chalk.blue.bold(CP))
console.log(chalk.blue("Wallet: ")+chalk.blue.bold(WP))

const getGatewayProfile = (profilename) => {
    const ccpPath = path.resolve(profilename);
    if (!fs.existsSync(ccpPath)) {
        throw new Error(`Gateway ${ccpPath} does not exist`);
    }

    const type = path.extname(ccpPath);

    if (JSON_EXT.exec(type)) {
        return JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
    } else if (YAML_EXT.exec(type)) {
        return yaml.safeLoad(fs.readFileSync(ccpPath, 'utf8'));
    } else {
        throw new Error(`Extension of ${ccpPath} not recognised`);
    }
};

const main = async () => {
   
    const wallet = await Wallets.newFileSystemWallet(WP);
    // Set connection options; identity and wallet
    const connectionOptions = {
        identity: id_name,
        wallet,
        discovery: { enabled: true, asLocalhost: false },
    };
   
    let gateway = new Gateway();
    // Connect to gateway using application specified parameters
    console.log(chalk.blue("Connecting to Network..."))
    await gateway.connect(getGatewayProfile(CP), connectionOptions);
    let network = await gateway.getNetwork(channel);
    console.log(chalk.blue("Connecting to Contract..."))
    let contract = await network.getContract(contract_name);

    console.log(chalk.blue("Submitting ")+chalk.blue.bold("org.hyperledger.fabric:GetMetadata"));
    console.log();
	let data = await contract.evaluateTransaction('org.hyperledger.fabric:GetMetadata');
    jsonData = JSON.parse(data.toString());
	console.log(prettyjson.render(jsonData));

    // console.log('sending....')
    // let promises = [];
    // let start = Date.now();
    // for (let x = 0; x < 100; x++) {

    //     // contract.createTransaction()
    //     let result = await contract.submitTransaction('AssetContract:create_asset', `id:${x+100}`, `BondAlias:${x}`);
    //     //et p = contract.submitTransaction('createMyAsset', `id:${x+6061}`,`BondAlias:${x}`);

    //    // console.log(result.toString())
    //     const issueResponse = await contract.submitTransaction('AssetContract:read_asset_value', `id:${x+100}`);
    //     // const issueResponse = await contract.submitTransaction('readMyAsset', `id:${x}`);
    //     //console.log(issueResponse.toString())
    // }
    // await Promise.all(promises);
    // let end = Date.now()
    // console.log(end - start);
    gateway.disconnect();

}

main().then(() => {
    process.exit(0);
}).catch((e) => {
    console.log(e);
    process.exit(-1);
})
