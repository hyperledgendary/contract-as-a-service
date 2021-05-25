/*
 * Copyright 2020 Hyperledger Fabric Contributors. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
package org.example.contracts;

import static java.nio.charset.StandardCharsets.UTF_8;

import java.util.logging.Logger;

import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.annotation.Contact;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Info;
import org.hyperledger.fabric.contract.annotation.License;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.contract.annotation.Transaction.TYPE;
import org.hyperledger.fabric.shim.ChaincodeException;

import org.example.adts.MyAsset;

@Contract(name = "MyAssetContract", info = @Info(title = "MyAssetContract contract", description = "My Smart Contract", version = "0.0.1", license = @License(name = "Apache-2.0", url = ""), contact = @Contact(email = "basic-java-20@example.com", name = "basic-java-20", url = "http://basic-java-20.me")))
public class MyAssetContract implements ContractInterface {

    private static Logger logger = Logger.getLogger(MyAssetContract.class.getName());

    /**
     * Required Default Constructor.
     */
    public MyAssetContract() {
        logger.info(() -> "MyAssetContract:<init>");
    }

    /**
     * Determines if the asset exists.
     * 
     * @param ctx       Transactional Context
     * @param myAssetId string id
     * @return true/false
     */
    @Transaction(intent = TYPE.EVALUATE)
    public boolean exists(final Context ctx, final String myAssetId) {
        logger.info(() -> "MyAsset:Exists#" + myAssetId);

        byte[] buffer = ctx.getStub().getState(MyAsset.createKey(myAssetId).toString());
        return (buffer != null && buffer.length > 0);
    }

    /**
     * Retrieves the asset
     * 
     * @param ctx       Transactional Context
     * @param myAssetId string id
     * @return asset
     */
    @Transaction(intent = TYPE.EVALUATE)
    public MyAsset retrieve(final Context ctx, final String myAssetId) {
        logger.info(() -> "MyAsset:Retrieve#" + myAssetId);

        byte[] buffer = ctx.getStub().getState(MyAsset.createKey(myAssetId).toString());
        if (buffer != null && buffer.length > 0) {
            throw new ChaincodeException("Asset Already Exists", myAssetId);
        }
        MyAsset a = MyAsset.fromBytes(buffer);
        return a;
    }

    /**
     * Creates a new asset with id and value.
     * 
     * @param ctx       Transaction Context
     * @param myAssetId id of asset
     * @param value     value of asset
     */
    @Transaction(intent = TYPE.SUBMIT)
    public void create(final Context ctx, final String myAssetId, final String value) {
        logger.info(() -> "MyAsset:Create#" + myAssetId);
        boolean exists = exists(ctx, myAssetId);
        if (exists) {
            throw new ChaincodeException("Asset Already Exists", myAssetId);
        }

        MyAsset asset = new MyAsset();
        asset.setValue(value);
        ctx.getStub().putState(MyAsset.createKey(myAssetId).toString(), asset.toJSONString().getBytes(UTF_8));
    }

    /**
     * Updates asset.
     * 
     * @param ctx       Transaction Context
     * @param myAssetId id of asset
     * @param newValue  value of asset
     */
    @Transaction(intent = TYPE.SUBMIT)
    public void update(final Context ctx, final String myAssetId, final String newValue) {
        logger.info(() -> "MyAsset:Update#" + myAssetId);
        boolean exists = exists(ctx, myAssetId);
        if (!exists) {
            throw new ChaincodeException("Asset Does Not Exist: " + myAssetId);
        }
        MyAsset asset = new MyAsset();
        asset.setValue(newValue);

        ctx.getStub().putState(MyAsset.createKey(myAssetId).toString(), asset.toJSONString().getBytes(UTF_8));
    }

    /**
     * Delete the asset.
     * 
     * @param ctx       Transaction Context
     * @param myAssetId asset id
     *
     */
    @Transaction(intent = TYPE.SUBMIT)
    public void delete(final Context ctx, final String myAssetId) {
        logger.info(() -> "MyAsset:Delete#" + myAssetId);
        boolean exists = exists(ctx, myAssetId);
        if (!exists) {
            throw new ChaincodeException("Asset Does Not Exist: " + myAssetId);
        }
        ctx.getStub().delState(MyAsset.createKey(myAssetId).toString());
    }

}
