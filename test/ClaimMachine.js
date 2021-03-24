const ClaimMachine = artifacts.require("MockScoreMachine");


let claimMachine
let epoch
const user0 = web3.utils.keccak256("ani")
const user1 = web3.utils.keccak256("ata")
const user2 = web3.utils.keccak256("hu")
const user3 = web3.utils.keccak256("moshe hakengeru")

const asset0 = web3.utils.keccak256("gold")
const asset1 = web3.utils.keccak256("silver")

contract("ClaimMachine", accounts => {
  beforeEach('initing', async () => {
    claimMachine = await ClaimMachine.new()
    epoch = Number((await claimMachine.EPOCH()).toString(10))
  })
  afterEach(async () => {
  })

  it("check score increase after update balance", async function() {
    let time = (await web3.eth.getBlock("latest")).timestamp    
    await claimMachine.updateScoreMock(user0, asset0, "6", time)
    time += 111

    const newScore = await claimMachine.getScore(user0, asset0, time)

    assert.equal(newScore.toString(10), "666", "unexpected new score")
  })

  it("check score decrease after update balance", async function() {
    let time = (await web3.eth.getBlock("latest")).timestamp
    await claimMachine.updateScoreMock(user0, asset0, "6", time)
    time += 111
    await claimMachine.updateScoreMock(user0, asset0, -3, time)
    time += 10

    const newScore = await claimMachine.getScore(user0, asset0, time)

    assert.equal(newScore.toString(10), (6*121 - 3*10).toString(), "unexpected new score")
  })
  
  it("test global score", async function() {
    let time = (await web3.eth.getBlock("latest")).timestamp

    await claimMachine.updateScoreMock(user0, asset0, "6", time)
    await claimMachine.updateScoreMock(user1, asset0, "7", time)
    await claimMachine.updateScoreMock(user0, asset1, "8", time)
    await claimMachine.updateScoreMock(user1, asset1, "9", time)

    time += 111

    let score00 = await claimMachine.getScore(user0, asset0, time)
    let score01 = await claimMachine.getScore(user0, asset1, time)    

    let score10 = await claimMachine.getScore(user1, asset0, time)
    let score11 = await claimMachine.getScore(user1, asset1, time)

    assert.equal(score00.toString(10), (6 * 111).toString(10))
    assert.equal(score10.toString(10), (7 * 111).toString(10))    
    assert.equal(score01.toString(10), (8 * 111).toString(10))
    assert.equal(score11.toString(10), (9 * 111).toString(10))

    let global0 = await claimMachine.getGlobalScore(asset0, time)
    let global1 = await claimMachine.getGlobalScore(asset1, time)

    assert.equal(global0.toString(10), (score00.add(score10)).toString(10))
    assert.equal(global1.toString(10), (score01.add(score11)).toString(10))    

    await claimMachine.updateScoreMock(user0, asset0, -1, time)
    await claimMachine.updateScoreMock(user1, asset0, -5, time)
    await claimMachine.updateScoreMock(user0, asset1, -8, time)
    await claimMachine.updateScoreMock(user1, asset1, -3, time)

    time += 112

    score00 = await claimMachine.getScore(user0, asset0, time)
    score01 = await claimMachine.getScore(user0, asset1, time)    

    score10 = await claimMachine.getScore(user1, asset0, time)
    score11 = await claimMachine.getScore(user1, asset1, time)

    assert.equal(score00.toString(10), (6 * (111 + 112) - 1 * (112)).toString())
    assert.equal(score10.toString(10), (7 * (111 + 112) - 5 * (112)).toString())    
    assert.equal(score01.toString(10), (8 * (111 + 112) - 8 * (112)).toString())
    assert.equal(score11.toString(10), (9 * (111 + 112) - 3 * (112)).toString())

    global0 = await claimMachine.getGlobalScore(asset0, time)
    global1 = await claimMachine.getGlobalScore(asset1, time)

    assert.equal(global0.toString(10), score00.add(score10).toString(10))
    assert.equal(global1.toString(10), score01.add(score11).toString(10))    
  })

  it("update score in 4 epochs", async function() {
    let balance = 0
    let time = (await web3.eth.getBlock("latest")).timestamp

    await updateAndIncreaseTime(user0, asset0, 123, time, time +=100, "1")
    await updateAndIncreaseTime(user0, asset0, 133, time, time += 200, "2")    
    await updateAndIncreaseTime(user0, asset0, 765, time, time += epoch, "3")
    await updateAndIncreaseTime(user0, asset0, 675, time, time +=epoch, "4")
    await updateAndIncreaseTime(user0, asset0, 3675, time, time += epoch, "5")
    await updateAndIncreaseTime(user0, asset0, 35, time, time += epoch + 9, "6")    
  })
})

async function updateAndIncreaseTime(user, asset, value, t0, t1, errMsg) {
  const balanceBefore = await claimMachine.getCurrentBalance(user, asset)
  const scoreBefore = await claimMachine.getScore(user, asset, t0)
  await claimMachine.updateScoreMock(user, asset, value, t0)
  const score = await claimMachine.getScore(user, asset, t1)
  const dTimeBN = new web3.utils.toBN(t1 - t0)
  const balanceBN = new web3.utils.toBN(value).add(balanceBefore)
  //console.log("balance", balanceBN.toString())
  //console.log("score after/before", score.toString(), scoreBefore.toString())
  //console.log(await claimMachine.getLatestScoreIndex(user, asset))
  //console.log("balance, dtime", balanceBN.toString(), dTimeBN.toString())
  assert.equal(score.sub(scoreBefore).toString(),(balanceBN.mul(dTimeBN)).toString(), errMsg)
}

async function increaseTime (addSeconds) {
  const util = require('util')
  const providerSendAsync = util.promisify((getTestProvider()).send).bind(
    getTestProvider()
  )

  /*
      getTestProvider().send({
              jsonrpc: "2.0",
              method: "evm_increaseTime",
              params: [addSeconds], id: 0
          }, console.log)
  */
  await providerSendAsync({
    jsonrpc: '2.0',
    method: 'evm_increaseTime',
    params: [addSeconds],
    id: 1
  })
}

async function mineBlock () {
  const util = require('util')
  const providerSendAsync = util.promisify((getTestProvider()).send).bind(
    getTestProvider()
  )
  await providerSendAsync({
    jsonrpc: '2.0',
    method: 'evm_mine',
    params: [],
    id: 1
  })
}

function getTestProvider () {
  return web3.currentProvider
}

async function getTxTime(operation) {
  const tx = await operation
  const blockHash = tx.receipt.blockHash
  return (await web3.eth.getBlock(blockHash)).timestamp
}