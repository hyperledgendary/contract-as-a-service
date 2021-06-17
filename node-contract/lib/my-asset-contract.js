/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

/**
 * Simple asset contract for testing. An asset as a value, an id, and an owner
 * All strings for simplicitly
 */
const { Contract } = require('fabric-contract-api');

class MyAssetContract extends Contract {

    async myAssetExists(ctx, myAssetId) {
        return (await this._assetExists(ctx,myAssetId)).exists
    }

    async _assetExists(ctx, myAssetId) {
        const buffer = await ctx.stub.getState(myAssetId);
        const exists = (!!buffer && buffer.length > 0);
        return { buffer, exists };
    }

    async createMyAsset(ctx, myAssetId, value, owner) {
        const { exists } = await this._assetExists(ctx, myAssetId);
        if (exists) {
            throw new Error(`The my asset ${myAssetId} already exists`);
        }
        const asset = { value, owner };
        const newbuffer = Buffer.from(JSON.stringify(asset));
        await ctx.stub.putState(myAssetId, newbuffer);
    }

    async readMyAsset(ctx, myAssetId) {
        const { buffer, exists } = await this._assetExists(ctx, myAssetId);
        if (!exists) {
            throw new Error(`The my asset ${myAssetId} does not exist`);
        }
    
        const asset = JSON.parse(buffer.toString());
        return asset;
    }

    async updateMyAsset(ctx, myAssetId, newValue) {
        const  { buffer, exists }  = await this._assetExists(ctx, myAssetId);
        if (!exists) {
            throw new Error(`The my asset ${myAssetId} does not exist`);
        }

        const asset = JSON.parse(buffer.toString());

        asset.value  = newValue;
        const newbuffer = Buffer.from(JSON.stringify(asset));
        await ctx.stub.putState(myAssetId, newbuffer);
    }

    async transferMyAsset(ctx, myAssetId, newOwner) {
        const  { buffer, exists }  = await this._assetExists(ctx, myAssetId);
        if (!exists) {
            throw new Error(`The my asset ${myAssetId} does not exist`);
        }

        const asset = JSON.parse(buffer.toString());
        asset.owner  = newOwner;
        const newbuffer = Buffer.from(JSON.stringify(asset));
        await ctx.stub.putState(myAssetId, newbuffer);
    }


    async deleteMyAsset(ctx, myAssetId) {
        const { exists }= await this._assetExists(ctx, myAssetId);
        if (!exists) {
            throw new Error(`The my asset ${myAssetId} does not exist`);
        }
        await ctx.stub.deleteState(myAssetId);
    }

}

module.exports = MyAssetContract;
