import * as t from "types/index";
import { ethers } from "ethers";
import { Withdrawn } from "types/Jar";
import { AllEvents } from "types/Context";

const { expectRevert, time, send, balance, ether } = require("@openzeppelin/test-helpers");

const {
  ZERO,
  ONE,
  TEN,
  ZERO_ADDRESS,
  ONE_WEEK,
  THOUSAND,
  ETH_ADDRESS,
  n2t_18,
} = require("../test-utils/constants");

const Jar: t.JarContract = artifacts.require("Jar");
const MockERC20Detailed: t.MockErc20DetailedContract = artifacts.require("MockERC20Detailed");
const MockConnector: t.MockConnectorContract = artifacts.require("MockConnector");

var chai = require("chai");
var assert = require("chai").assert;
var expect = require("chai").expect;
const BN = require("bn.js");

chai.use(require("chai-bn")(BN));

contract("Jar", async (accounts) => {
  let jar: t.JarInstance;
  let connector: t.MockConnectorInstance;

  beforeEach(async () => {
    connector = await MockConnector.new();
    const block = await web3.eth.getBlock(await web3.eth.getBlockNumber());
    const nowTimestamp = block.timestamp;

    jar = await Jar.new(1, new BN(nowTimestamp).add(ONE_WEEK), connector.address);
  });

  it("should receive ETH at Jar", async () => {
    await expectEtherBalance(jar.address, ZERO);

    await send.ether(accounts[0], jar.address, ether(ONE));

    await expectEtherBalance(jar.address, ether(ONE));
  });

  it("should fail when withdrawTimeout is incorrect", async () => {
    await expectRevert(Jar.new(1, 100, ZERO_ADDRESS), "incorrect-withdraw-timelock");
  });

  context("withdraw()", async () => {
    const user1 = accounts[8];
    const user2 = accounts[9];

    // create token
    let token: t.MockErc20DetailedInstance;

    beforeEach("user setup before", async () => {
      // 1. Create Mock ERC20 token
      token = await MockERC20Detailed.new("Mock Token", "MKT", 18, THOUSAND);

      // 2. Transfer 10 tokens to Jar contract
      await token.transfer(jar.address, n2t_18(10));

      // 3. check token balance of Jar contract
      await expectTokenBalance(jar.address, token, n2t_18(10));

      // 4. Transfer 10 ETH to Jar
      await send.ether(accounts[0], jar.address, ether(TEN));

      // 5. check ETH balance of Jar contract
      await expectEtherBalance(jar.address, ether(TEN));
    });

    it("should not allow withdraw before withdrawTimeout", async () => {
      // 1. try to withdraw before timeout
      await expectRevert(jar.withdraw(user1, token.address, { from: user1 }), "withdrawal-locked");

      // 2. ensure that the balance is not affected
      await expectTokenBalance(jar.address, token, n2t_18(10));

      // 3. ensure that withdrawn status not changed
      await expectWithdrawn(user1, token.address, false);
    });

    it("should fail withdraw when ethExit not called", async () => {
      //1. increase the time to enable withdrawal
      await time.increase(ONE_WEEK);

      //2. try to withdraw, must fail
      await expectRevert(
        jar.withdraw(user1, token.address, { from: user1 }),
        "eth-exit-not-called-before",
      );
    });

    it("should not allow withdraw same token again for a user", async () => {
      //1. increase block time
      await time.increase(ONE_WEEK);

      //2. delegate ethExit
      await jar.delegateEthExit();

      //3. user withdraw
      await jar.withdraw(user1, token.address, { from: user1 });

      //4. check expected balance
      await expectTokenBalance(jar.address, token, n2t_18(9));
      await expectTokenBalance(user1, token, n2t_18(1));
      await expectWithdrawn(user1, token.address, true);

      //5. user again try to withdraw same token, must fail
      await expectRevert(
        jar.withdraw(user1, token.address, { from: user1 }),
        "user-withdrew-rewards-before",
      );

      //7. validate balances
      await expectTokenBalance(jar.address, token, n2t_18(9));
      await expectTokenBalance(user1, token, n2t_18(1));
      await expectWithdrawn(user1, token.address, true);
    });

    it("should not allow withdraw ETH again from a user", async () => {
      //1. increase block time
      await time.increase(ONE_WEEK);

      //2. delegate ethExit
      await jar.delegateEthExit();

      //3. Expected balance
      await expectEtherBalance(jar.address, ether(TEN));
      let user1EthBal = await balance.current(user1);
      await expectEtherBalance(user1, user1EthBal);
      await expectWithdrawn(user1, ETH_ADDRESS, false);

      // 4. withdraw
      let tx = await jar.withdraw(user1, ETH_ADDRESS, { from: user1 });

      // 5. check expected balance
      await expectEtherBalance(jar.address, ether("9"));
      await expectEtherBalanceAfterTx(user1, user1EthBal.add(ether(ONE)), tx);
      await expectWithdrawn(user1, ETH_ADDRESS, true);

      // 6. withdraw again must fail
      await expectRevert(
        jar.withdraw(user1, ETH_ADDRESS, { from: user1 }),
        "user-withdrew-rewards-before",
      );

      // 7. check expected balance
      await expectEtherBalance(jar.address, ether("9"));
      await expectWithdrawn(user1, ETH_ADDRESS, true);
    });

    it("should allow withdraw ETH", async () => {
      //1. increase block time
      await time.increase(ONE_WEEK);

      //2. delegate ethExit
      await jar.delegateEthExit();

      //3. Expected balance
      await expectEtherBalance(jar.address, ether(TEN));
      const user1EthBal = await balance.current(user1);
      await expectEtherBalance(user1, user1EthBal);
      await expectWithdrawn(user1, ETH_ADDRESS, false);

      // 4. withdraw
      const tx = await jar.withdraw(user1, ETH_ADDRESS, { from: user1 });

      // 5. check expected balance
      await expectEtherBalance(jar.address, ether("9"));
      await expectEtherBalanceAfterTx(user1, user1EthBal.add(ether(ONE)), tx);
      await expectWithdrawn(user1, ETH_ADDRESS, true);
    });

    it("should allow withdraw ETH on behalf other user", async () => {
      //1. increase block time
      await time.increase(ONE_WEEK);

      //2. delegate ethExit
      await jar.delegateEthExit();

      //3. Expected balance
      await expectEtherBalance(jar.address, ether(TEN));
      const user1EthBal = await balance.current(user1);
      await expectEtherBalance(user1, user1EthBal);
      await expectWithdrawn(user1, ETH_ADDRESS, false);

      // 4. user2 withdrawing on behalf of user1
      await jar.withdraw(user1, ETH_ADDRESS, { from: user2 });

      // 5. check expected balance
      await expectEtherBalance(jar.address, ether("9"));
      await expectEtherBalance(user1, user1EthBal.add(ether(ONE)));
      await expectWithdrawn(user1, ETH_ADDRESS, true);
    });

    it("should allow withdraw ERC20", async () => {
      //1. increase block time
      await time.increase(ONE_WEEK);

      //2. delegate ethExit
      await jar.delegateEthExit();

      //3. Expected balance
      await expectTokenBalance(jar.address, token, n2t_18(10));
      await expectTokenBalance(user1, token, ZERO);
      await expectWithdrawn(user1, token.address, false);

      //4. user withdraw
      await jar.withdraw(user1, token.address, { from: user1 });

      //5. check expected balance
      await expectTokenBalance(jar.address, token, n2t_18(9));
      await expectTokenBalance(user1, token, n2t_18(1));
      await expectWithdrawn(user1, token.address, true);
    });

    it("should allow withdraw ETH on behalf other user", async () => {
      //1. increase block time
      await time.increase(ONE_WEEK);

      //2. delegate ethExit
      await jar.delegateEthExit();

      //3. Expected balance
      await expectTokenBalance(jar.address, token, n2t_18(10));
      await expectTokenBalance(user1, token, ZERO);
      await expectWithdrawn(user1, token.address, false);

      //4. user2 withdrawing on behalf of user1
      await jar.withdraw(user1, token.address, { from: user2 });

      //5. check expected balance
      await expectTokenBalance(jar.address, token, n2t_18(9));
      await expectTokenBalance(user1, token, n2t_18(1));
      await expectWithdrawn(user1, token.address, true);
    });
  });

  context("delegateEthExit()", async () => {
    it("should succeed ethExit delegate call to connector");

    it("should fail when connector address is incorrect");

    it("should not set ethExit status when called before withdrawTimeout");

    it("should set ethExit status when called after withdrawTimeout");
  });

  // Helper functions
  //===================
  async function expectWithdrawn(account: string, token: string, expValue: boolean) {
    const withdrawn = await jar.withdrawn(account, token);
    await expect(expValue).to.be.equal(withdrawn);
  }

  async function expectTokenBalance(
    account: string,
    token: t.MockErc20DetailedInstance,
    expBalance: BN,
  ) {
    const bal = await token.balanceOf(account);
    expect(expBalance).to.be.bignumber.equal(bal);
  }

  async function expectEtherBalance(account: string, expBalance: BN) {
    const bal = await balance.current(account);
    expect(expBalance).to.be.bignumber.equal(bal);
  }

  async function expectEtherBalanceAfterTx(
    account: string,
    expBalance: BN,
    tx: Truffle.TransactionResponse<Truffle.AnyEvent>,
  ) {
    let bal = await balance.current(account);
    const gasPrice = new BN(web3.utils.toWei("8", "gwei"));
    const txFee = new BN(tx.receipt.gasUsed).mul(gasPrice);

    bal = bal.add(txFee);
    expect(expBalance).to.be.bignumber.equal(bal);
  }
});
