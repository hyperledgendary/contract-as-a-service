/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const MyAssetContract = require('./lib/my-asset-contract');
const SetupContract = require('./lib/setup');
module.exports.MyAssetContract = MyAssetContract;
module.exports.SetupContract = SetupContract

module.exports.contracts = [ MyAssetContract,SetupContract ];
