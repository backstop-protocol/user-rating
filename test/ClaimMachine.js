const ClaimMachine = artifacts.require("ClaimMachine");

contract("ClaimMachine", accounts => {
  it("deploy new claim machine", async () =>
    console.log((await ClaimMachine.new()).address)
  );
});