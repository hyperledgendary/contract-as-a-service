// Apache-2
const fs = require('fs')
const path = require('path')
const chalk = require('chalk')
const JSON_EXT = /json/gi;
const YAML_EXT = /ya?ml/gi;
const faker = require('faker')
const prettyjson = require("prettyjson-256");
// Credentials that are required
prettyjson.init({ alphabetizeKeys: true });

const { Wallets, Gateway } = require('fabric-network');

const env = require('env-var');
const wallet_dir = env.get("WALLET_DIR").required().asString();
const id_name = env.get("ID_NAME").required().asString();
const gateway_profile = env.get("GATEWAY_PROFILE").required().asString();
const contract_name = env.get("CONTRACT").required().asString();
const channel = env.get("CHANNEL").required().asString();

const CP = path.resolve(gateway_profile);
const WP = path.resolve(wallet_dir);

console.log(chalk.blue("Gateway Connection Profile: ") + chalk.blue.bold(CP))
console.log(chalk.blue("Wallet: ") + chalk.blue.bold(WP))

// driver constants
const MAX_PRODUCT_NUMBER = 10000;
// somewhere between 1 and 60 seconds
const MIN_INTERVAL = 1000;
const MAX_INTERVAL = 1000 * 60;


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

const drivefn = async () => {
    let productId = Math.floor(Math.random() * MAX_PRODUCT_NUMBER);
    let asset = faker.commerce.productName();
    let exists = await contract.evaluateTransaction('myAssetExists', `id:${productId}`);
    if (exists) {
        await contract.submitTransaction('updateMyAsset', `id:${productId}`, `${asset}`);
    } else {
        await contract.submitTransaction('createMyAsset', `id:${productId}`, `${asset}`);
    }

}
let contract;

const runInterval = async () => {
    console.log(`runInterval`);
    const timeoutFunction = async () => {
        await drivefn();
    };



    await setTimeoutAsync(timeoutFunction, delay);
};

let runFn = async (delay) => {

    return new Promise((resolve, reject) => {
        setTimeout(async () => {
            await drivefn();
            resolve();
        }, delay)
    })
}

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
    contract = await network.getContract(contract_name);

    try {
        const delay = Math.floor(Math.random() * (MAX_INTERVAL - MIN_INTERVAL + 1)) + MIN_INTERVAL;
        // await runFn(delay);
        await drivefn();
        console.log('drive called')
    } catch (e) {
        console.log(e);
    } finally {
        gateway.disconnect();
    }



}

main().then(() => {
    process.exit(0);
}).catch((e) => {
    console.log(e);
    process.exit(-1);
})
