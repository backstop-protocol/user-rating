const BN = require("bn.js");

// Time
export const ONE_MINUTE = new BN(60);
export const ONE_HOUR = new BN(60).mul(ONE_MINUTE);
export const ONE_DAY = new BN(24).mul(ONE_HOUR);
export const ONE_WEEK = new BN(7).mul(ONE_DAY);

// constant value
export const ZERO = new BN(0);

// address
export const ZERO_ADDRESS: string =
  "0x0000000000000000000000000000000000000000";
export const DEAD_ADDRESS: string =
  "0x0000000000000000000000000000000000000001";

// amount
export const ONE_ETH = new BN(web3.utils.toWei("1", "ether"));
