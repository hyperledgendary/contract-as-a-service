/*
 * SPDX-License-Identifier: Apache-2.0
 */

package org.example;

import java.io.IOException;
import org.hyperledger.fabric.contract.ContractRouter;
import org.hyperledger.fabric.shim.ChaincodeServer;
import org.hyperledger.fabric.shim.ChaincodeServerProperties;
import org.hyperledger.fabric.shim.NettyChaincodeServer;

public class ContractBootstrap {

    private static final String CHAINCODE_SERVER_ADDRESS = "CHAINCODE_SERVER_ADDRESS";
    private static final String CHAINCODE_ID = "CHAINCODE_ID";
    private static final String CORE_PEER_TLS_ENABLED = "CORE_PEER_TLS_ENABLED";
    private static final String CORE_PEER_TLS_ROOTCERT_FILE = "CORE_PEER_TLS_ROOTCERT_FILE";
    private static final String ENV_TLS_CLIENT_KEY_FILE = "CORE_TLS_CLIENT_KEY_FILE";
    private static final String ENV_TLS_CLIENT_CERT_FILE = "CORE_TLS_CLIENT_CERT_FILE";


    public static void main(String[] args) throws Exception {
        ChaincodeServerProperties chaincodeServerProperties = new ChaincodeServerProperties();

        final String chaincodeServerPort = System.getenv(CHAINCODE_SERVER_ADDRESS);
        if (chaincodeServerPort == null || chaincodeServerPort.isEmpty()) {
            throw new IOException("chaincode server port not defined in system env. for example 'CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999'");
        }

        final int port = Integer.parseInt(chaincodeServerPort.split(":")[1]);
        chaincodeServerProperties.setPortChaincodeServer(port);

        final String coreChaincodeIdName = System.getenv(CHAINCODE_ID);
        if (coreChaincodeIdName == null || coreChaincodeIdName.isEmpty()) {
            throw new IOException("core peer address not defined in system env. for example 'CHAINCODE_ID=externalcc:06d1d324e858751d6eb4211885e9fd9ff74b62cb4ffda2242277fac95d467033'");
        }

        boolean tlsEnabled = Boolean.parseBoolean(System.getenv(CORE_PEER_TLS_ENABLED));
        if (tlsEnabled) {
            // String tlsClientRootCertPath = System.getenv(CORE_PEER_TLS_ROOTCERT_FILE);
            String tlsClientKeyFile = System.getenv(ENV_TLS_CLIENT_KEY_FILE);
            String tlsClientCertFile = System.getenv(ENV_TLS_CLIENT_CERT_FILE);

            // set values on the server properties
            chaincodeServerProperties.setTlsEnabled(true);
            chaincodeServerProperties.setKeyFile(tlsClientKeyFile);
            chaincodeServerProperties.setKeyCertChainFile(tlsClientCertFile);
        }

        ContractRouter contractRouter = new ContractRouter(new String[] {"-i", coreChaincodeIdName});
        ChaincodeServer chaincodeServer = new NettyChaincodeServer(contractRouter, chaincodeServerProperties);

        contractRouter.startRouterWithChaincodeServer(chaincodeServer);
    }

}
