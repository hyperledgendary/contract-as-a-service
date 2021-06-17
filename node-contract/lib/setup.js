/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

/**
 * Utility to setup the ledger for testing
 */
const { Contract } = require('fabric-contract-api');

const MyAssetContract = require('./my-asset-contract');

class SetupContract extends Contract {
    // InitLedger creates sample assets in the ledger
    async initLedger(ctx) {
        const ac = new MyAssetContract();

        const assets = [
            {
                assetID: 'asset1',
                owner: 'Tom',
                value: '#100'
            },
            {
                assetID: 'asset2',
                owner: 'Brad',
                value: '#100'
            },
            {
                assetID: 'asset3',
       
                owner: 'Jin Soo',
                value: '#50'
            },
            {
                assetID: 'asset4',
        

                owner: 'Max',
                value: '#200'
            },
            {
                assetID: 'asset5',
        
         
                owner: 'Adriana',
                value: '#250'
            },
            {
                assetID: 'asset6',

                owner: 'Michel',
                value: '#250'
            },
        ];

        for (const asset of assets) {
            await ac.createMyAsset(
                ctx,
                asset.assetID,
                asset.owner,
                asset.value
            );
        }
    }
}

module.exports = SetupContract;