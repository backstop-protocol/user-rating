const BN = require("bn.js");

import "@openzeppelin/test-helpers/src/constants.js";

// Time
export const ONE_MINUTE = new BN(60);
export const ONE_HOUR = new BN(60).mul(ONE_MINUTE);
export const ONE_DAY = new BN(24).mul(ONE_HOUR);
export const ONE_WEEK = new BN(7).mul(ONE_DAY);

// constant value
export const ZERO = new BN(0);
export const ONE = new BN(1);
export const TEN = new BN(10);
export const HUNDRED = new BN(100);
export const THOUSAND = new BN(1000);

// address
export const ZERO_ADDRESS: string = "0x0000000000000000000000000000000000000000";
export const DEAD_ADDRESS: string = "0x0000000000000000000000000000000000000001";
export const ETH_ADDRESS: string = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

// Tokens

// Number to tokens of decimals
export function n2t_18(num: number): BN {
  return new BN(num).mul(new BN(10).pow(new BN(18)));
}
