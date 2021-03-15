/*
 * Copyright 2020 Hyperledger Fabric Contributors. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
package org.example.adts;

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


@Contract(name = "MyAsset",
    info = @Info(title = "MyAssetService contract",
                description = "My Smart Contract",
                version = "0.0.1",
                license =
                        @License(name = "Apache-2.0",
                                url = ""),
                                contact =  @Contact(email = "basic-java-20@example.com",
                                                name = "basic-java-20",
                                                url = "http://basic-java-20.me")))
public class MyAssetService implements ContractInterface {

    private static Logger logger = Logger.getLogger(MyAssetService.class.getName());

    /**
     * Required Default Constructor.
     */
    public MyAssetService() {
        logger.info(()->"MyAssetService:<init>");
    }

    /**
     * Determines if the asset exists.
     * @param ctx Transactional Context
     * @param myAssetId  string id
     * @return true/false
     */
    @Transaction(intent = TYPE.EVALUATE)
    public boolean exists(final Context ctx, final String myAssetId) {
        logger.info(()-> "MyAsset:Exists#"+myAssetId);

        byte[] buffer = ctx.getStub().getState(MyAsset.createKey(myAssetId).toString());
        return (buffer != null && buffer.length > 0);
    }

    /**
     * Creates a new asset with id and value.
     * @param ctx Transaction Context
     * @param myAssetId  id of asset
     * @param value value of asset
     */
    @Transaction(intent = TYPE.SUBMIT)
    public void createInt(final Context ctx, final String myAssetId, final int value) {
        logger.info(()-> "MyAsset:Create#"+myAssetId);
        boolean exists = exists(ctx, myAssetId);
        if (exists) {
            throw new ChaincodeException("Asset Already Exists",myAssetId);
        }
    
        MyAsset asset = new MyAsset();
        asset.setValue(value);
        ctx.getStub().putState(MyAsset.createKey(myAssetId).toString(), asset.toJSONString().getBytes(UTF_8));
    }

        /**
     * Creates a new asset with id and value.
     * @param ctx Transaction Context
     * @param myAssetId  id of asset
     * @param value value of asset
     */
    @Transaction(intent = TYPE.SUBMIT)
    public void createJSON(final Context ctx, final String myAssetId, final String value) {
        logger.info(()-> "MyAsset:CreateJSON#"+myAssetId);
        boolean exists = exists(ctx, myAssetId);
        if (exists) {
            throw new ChaincodeException("Asset Already Exists "+myAssetId,myAssetId);
        }

        // do this to check that all is well, and of course this might well be a template
        // TODO
        MyAsset asset =  MyAsset.fromJSONString(value);
        
        ctx.getStub().putState(MyAsset.createKey(myAssetId).toString(), asset.toJSONString().getBytes(UTF_8));
    }
    
    /**
     * Retreives asset.
     * @param ctx Transactional Context
     * @param myAssetId  string id
     * @return Asset object found
     * @throws Error if the asset does not exist
     */
    @Transaction(intent = TYPE.EVALUATE)
    public MyAsset retrieve(final Context ctx, final String myAssetId) {
        logger.info(()-> "MyAsset:Retrieve#"+myAssetId);
        boolean exists = exists(ctx, myAssetId);
        if (!exists) {
            throw new ChaincodeException("Asset Does Not Exist: "+myAssetId);
        }

        MyAsset newAsset = MyAsset.fromJSONString(new String(ctx.getStub().getState(MyAsset.createKey(myAssetId).toString()), UTF_8));
        return newAsset;
    }

    /**
     * Updates asset.
     * @param ctx Transaction Context
     * @param myAssetId  id of asset
     * @param newValue value of asset
     */
    @Transaction(intent = TYPE.SUBMIT)
    public void update(final Context ctx, final String myAssetId, final int newValue) {
        logger.info(()-> "MyAsset:Update#"+myAssetId);
        boolean exists = exists(ctx, myAssetId);
        if (!exists) {
            throw new ChaincodeException("Asset Does Not Exist: "+myAssetId);
        }
        MyAsset asset = new MyAsset();
        asset.setValue(newValue);

        ctx.getStub().putState(MyAsset.createKey(myAssetId).toString(), asset.toJSONString().getBytes(UTF_8));
    }

    /**
     * Delete the asset.
     * @param ctx Transaction Context
     * @param myAssetId asset id
     *
     */
    @Transaction(intent = TYPE.SUBMIT)
    public void delete(final Context ctx, final String myAssetId) {
        logger.info(()-> "MyAsset:Delete#"+myAssetId);
        boolean exists = exists(ctx, myAssetId);
        if (!exists) {
            throw new ChaincodeException("Asset Does Not Exist: "+myAssetId);
        }
        ctx.getStub().delState(MyAsset.createKey(myAssetId).toString());
    }

}
