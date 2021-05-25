/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Context, Contract, Info, Returns, Transaction } from 'fabric-contract-api';
import { MyAsset } from './my-asset';

@Info({ title: 'MyAssetContract', description: 'My Smart Contract' })
export class MyAssetContract extends Contract {
    @Transaction(false)
    @Returns('boolean')
    public async exists(ctx: Context, myAssetId: string): Promise<boolean> {
        const data: Uint8Array = await ctx.stub.getState(myAssetId);
        return !!data && data.length > 0;
    }

    @Transaction()
    public async create(ctx: Context, myAssetId: string, value: string): Promise<void> {
        const exists: boolean = await this.exists(ctx, myAssetId);
        if (exists) {
            throw new Error(`The my asset ${myAssetId} already exists`);
        }
        const myAsset: MyAsset = new MyAsset();
        myAsset.value = value;
        const buffer: Buffer = Buffer.from(JSON.stringify(myAsset));
        await ctx.stub.putState(myAssetId, buffer);
    }

    @Transaction(false)
    @Returns('MyAsset')
    public async retrieve(ctx: Context, myAssetId: string): Promise<MyAsset> {
        const exists: boolean = await this.exists(ctx, myAssetId);
        if (!exists) {
            throw new Error(`The my asset ${myAssetId} does not exist`);
        }
        const data: Uint8Array = await ctx.stub.getState(myAssetId);
        const myAsset: MyAsset = JSON.parse(data.toString()) as MyAsset;
        return myAsset;
    }

    @Transaction()
    public async update(ctx: Context, myAssetId: string, newValue: string): Promise<void> {
        const exists: boolean = await this.exists(ctx, myAssetId);
        if (!exists) {
            throw new Error(`The my asset ${myAssetId} does not exist`);
        }
        const myAsset: MyAsset = new MyAsset();
        myAsset.value = newValue;
        const buffer: Buffer = Buffer.from(JSON.stringify(myAsset));
        await ctx.stub.putState(myAssetId, buffer);
    }

    @Transaction()
    public async delete(ctx: Context, myAssetId: string): Promise<void> {
        const exists: boolean = await this.exists(ctx, myAssetId);
        if (!exists) {
            throw new Error(`The my asset ${myAssetId} does not exist`);
        }
        await ctx.stub.deleteState(myAssetId);
    }
}
