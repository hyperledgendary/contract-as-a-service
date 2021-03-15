/*
 * Copyright 2020 Hyperledger Fabric Contributors. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
package org.example.contracts;

import java.util.Iterator;
import java.util.logging.Logger;

import org.example.adts.MyAsset;
import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.annotation.Contact;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Default;
import org.hyperledger.fabric.contract.annotation.Info;
import org.hyperledger.fabric.contract.annotation.License;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.contract.annotation.Transaction.TYPE;
import org.hyperledger.fabric.shim.ChaincodeStub;
import org.hyperledger.fabric.shim.ledger.CompositeKey;
import org.hyperledger.fabric.shim.ledger.KeyValue;
import org.hyperledger.fabric.shim.ledger.QueryResultsIterator;

@Contract(name = "ValueContract", info = @Info(title = "Value Sum contract", description = "My Smart Contract", version = "0.0.1", license = @License(name = "Apache-2.0", url = ""), contact = @Contact(email = "basic-java-20@example.com", name = "basic-java-20", url = "http://basic-java-20.me")))
@Default
public class ValueContract implements ContractInterface {

    private static Logger logger = Logger.getLogger(ValueContract.class.getName());

    public ValueContract() {
        logger.info(()->"ValueContract:<init>");
    }


    @Transaction(intent = TYPE.SUBMIT)
    public String responseUpdate(final Context ctx,String hello) {
        ChaincodeStub stub = ctx.getStub();
        String r = stub.getStringState("Phrase");
        stub.putStringState("Phrase", hello);
        return r;
    }

    @Transaction(intent = TYPE.EVALUATE)
    public int sumValues(final Context ctx) {
        logger.info(()->"SumValues");
        CompositeKey key = new CompositeKey(MyAsset.class.getSimpleName(), new String[]{} );

        QueryResultsIterator<KeyValue> results = ctx.getStub().getStateByPartialCompositeKey(key);
        Iterator<KeyValue> it = results.iterator();

        int sum=0;
        int count=0;
        while (it.hasNext()){
            count++;
            MyAsset asset  = MyAsset.fromBytes(it.next().getValue());
            sum += asset.getValue();
        }

        logger.info("Sum "+sum+" from counting "+count+" assets");
        return sum;
    }

    @Transaction(intent = TYPE.EVALUATE)
    public double averageValues(final Context ctx){
        logger.info(()->"SumValues");
        CompositeKey key = new CompositeKey(MyAsset.class.getSimpleName(), new String[]{} );

        QueryResultsIterator<KeyValue> results = ctx.getStub().getStateByPartialCompositeKey(key);
        Iterator<KeyValue> it = results.iterator();

        int sum=0;
        int count=0;
        while (it.hasNext()){
            count++;
            MyAsset asset  = MyAsset.fromBytes(it.next().getValue());
            sum += asset.getValue();
        }
        double average = sum/count;
        logger.info("Average "+average+" from counting "+count+" assets");
        return average;

    }
}
