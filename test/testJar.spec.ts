import * as t from "types/index";

const { expectRevert } = require("@openzeppelin/test-helpers");

const {
  ZERO,
  ZERO_ADDRESS,
  ONE_WEEK,
  ONE_ETH,
} = require("../test-utils/constants");

const Jar: t.JarContract = artifacts.require("Jar");

var chai = require("chai");
var assert = require("chai").assert;
var expect = require("chai").expect;
const BN = require("bn.js");

chai.use(require("chai-bn")(BN));

contract("Jar", async (accounts) => {
  let jar: t.JarInstance;

  before(async () => {
    const connector: string = ZERO_ADDRESS;
    const block = await web3.eth.getBlock(0);
    const nowTimestamp = block.timestamp;

    jar = await Jar.new(1, new BN(nowTimestamp).add(ONE_WEEK), connector);
  });

  it("should receive ETH", async () => {
    let ethBal = await web3.eth.getBalance(jar.address);
    expect(ZERO).to.be.bignumber.equal(ethBal);

    await web3.eth.sendTransaction({
      from: accounts[0],
      value: ONE_ETH,
      to: jar.address,
    });

    ethBal = await web3.eth.getBalance(jar.address);
    expect(ONE_ETH).to.be.bignumber.equal(ethBal);
  });

  it("should fail when withdrawTimeout is incorrect", async () => {
    await expectRevert(
      Jar.new(1, 100, ZERO_ADDRESS),
      "incorrect-withdraw-timelock"
    );
  });

  context("withdraw()", async () => {
    before("user setup before", async () => {
      const user = accounts[9];
      // create token
    });

    it("should not allow withdraw before withdrawTimeout", async () => {
      //jar.withdraw();
    });

    it("should fail withdraw when ethExit not called");

    it("should not allow withdraw same token again for a user");

    it("should allow withdraw ETH");

    it("should allow withdraw ERC20");
  });

  context("delegateEthExit()", async () => {
    it("should succeed ethExit delegate call to connector");

    it("should fail when connector address is incorrect");

    it("should not set ethExit status when called before withdrawTimeout");

    it("should set ethExit status when called after withdrawTimeout");
  });
});
