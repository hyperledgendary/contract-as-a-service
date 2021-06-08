/*
SPDX-License-Identifier: Apache-2.0
*/

package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strconv"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"github.com/hyperledger/fabric-samples/asset-transfer-basic/chaincode-go/chaincode"
)

func main() {

	fmt.Printf("Starting chaincode\n")

	assetChaincode, err := contractapi.NewChaincode(&chaincode.SmartContract{})
	if err != nil {
		log.Panicf("Error creating asset-transfer-basic chaincode: %v", err)
	}
	fmt.Printf("Created Contract\n")

	tlsProps, err := getTlsProps()
	if err != nil {
		log.Panicf("Error creating getting TLS properties: %v", err)
	}
	fmt.Printf("Creating Server\n")

	server := &shim.ChaincodeServer{
		CCID:     os.Getenv("CHAINCODE_ID"),
		Address:  os.Getenv("CHAINCODE_SERVER_ADDRESS"),
		CC:       assetChaincode,
		TLSProps: tlsProps,
	}

	out, err := json.Marshal(server)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(out))

	fmt.Printf("Starting server\n")
	err = server.Start()
	if err != nil {
		fmt.Printf("Error starting go-contract chaincode: %s", err)
	}

}

func getTlsProps() (shim.TLSProperties, error) {

	tlsEnabled, err := strconv.ParseBool(os.Getenv("CORE_PEER_TLS_ENABLED"))
	if err != nil {
		tlsEnabled = false
	}

	if !tlsEnabled {
		return shim.TLSProperties{Disabled: true}, nil
	}

	var key []byte
	path, set := os.LookupEnv("CORE_TLS_CLIENT_KEY_FILE")
	if set {
		key, err = ioutil.ReadFile(path)
		if err != nil {
			return shim.TLSProperties{}, fmt.Errorf("failed to read private key file: %s", err)
		}

	} else {
		data, err := ioutil.ReadFile(os.Getenv("CORE_TLS_CLIENT_KEY_PATH"))
		if err != nil {
			return shim.TLSProperties{}, fmt.Errorf("failed to read private key file: %s", err)
		}
		key, err = base64.StdEncoding.DecodeString(string(data))
		if err != nil {
			return shim.TLSProperties{}, fmt.Errorf("failed to decode private key file: %s", err)
		}
	}

	var cert []byte
	path, set = os.LookupEnv("CORE_TLS_CLIENT_CERT_FILE")
	if set {
		cert, err = ioutil.ReadFile(path)
		if err != nil {
			return shim.TLSProperties{}, fmt.Errorf("failed to read public key file: %s", err)
		}
	} else {
		data, err := ioutil.ReadFile(os.Getenv("CORE_TLS_CLIENT_CERT_PATH"))
		if err != nil {
			return shim.TLSProperties{}, fmt.Errorf("failed to read public key file: %s", err)
		}
		cert, err = base64.StdEncoding.DecodeString(string(data))
		if err != nil {
			return shim.TLSProperties{}, fmt.Errorf("failed to decode public key file: %s", err)
		}
	}

	root, err := ioutil.ReadFile(os.Getenv("CORE_PEER_TLS_ROOTCERT_FILE"))
	if err != nil {
		return shim.TLSProperties{}, fmt.Errorf("failed to read root cert file: %s", err)
	}

	return shim.TLSProperties{
		Disabled:      false,
		Key:           key,
		Cert:          cert,
		ClientCACerts: root,
	}, nil
}
