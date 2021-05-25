/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Object as DataType, Property } from 'fabric-contract-api';

@DataType()
export class MyAsset {
    @Property()
    public value: string;
}
