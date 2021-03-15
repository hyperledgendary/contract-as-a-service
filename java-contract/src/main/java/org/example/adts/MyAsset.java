/*
 * Copyright 2020 Hyperledger Fabric Contributors. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package org.example.adts;

import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Property;
import org.hyperledger.fabric.shim.ledger.CompositeKey;
import static java.nio.charset.StandardCharsets.UTF_8;
import com.owlike.genson.Genson;

@DataType()
public class MyAsset {

    private static final Genson GENSON = new Genson();

    @Property()
    private int value;

    private String uid;

    public void setUid(String uid){
        this.uid = uid;
    }

    public String getUid()  {
        return this.uid;
    }
    
    public CompositeKey getKey() {
        return new CompositeKey(MyAsset.class.getSimpleName(), new String[]{ this.uid });
    }

    public static CompositeKey createKey(String[] attributes) {
        return new CompositeKey(MyAsset.class.getSimpleName(), attributes);
    }

    public static CompositeKey createKey(String attribute) {
        return new CompositeKey(MyAsset.class.getSimpleName(), new String[] {attribute});
    }
    /**
     * Constructor - creates empty asset.
     */
    public MyAsset() {
    }

    /**
     *
     * @return String value
     */
    public int getValue() {
        return value;
    }

    /**
     * @param value String value
     */
    public void setValue(final int value) {
        this.value = value;
    }

    /**
     * @return String JSON
     */
    public String toJSONString() {
        return GENSON.serialize(this).toString();
    }

    /**
     * Constructs new asset from JSON String.
     * @param json Asset format.
     * @return MyAsset
     */
    public static MyAsset fromJSONString(final String json) {
        MyAsset asset = GENSON.deserialize(json, MyAsset.class);
        return asset;
    }

        /**
     * Constructs new asset from JSON String.
     * @param json Asset format.
     * @return MyAsset
     */
    public static MyAsset fromBytes(final byte[] bytes) {
        MyAsset asset = GENSON.deserialize(new String(bytes,UTF_8), MyAsset.class);
        return asset;
    }
}
