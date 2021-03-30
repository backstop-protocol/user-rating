const ScoreMachine = artifacts.require("MockScoreMachine");


let scoreMachine
const user0 = web3.utils.keccak256("ani")
const user1 = web3.utils.keccak256("ata")
const user2 = web3.utils.keccak256("hu")
const user3 = web3.utils.keccak256("moshe hakengeru")

const asset0 = web3.utils.keccak256("gold")
const asset1 = web3.utils.keccak256("silver")

const startBlock = 12139493

contract("ScoreMachine", accounts => {
  beforeEach('initing', async () => {
    scoreMachine = await ScoreMachine.new()
    // 12k coins per block for asset 0
    await scoreMachine.setSpeedMock(asset0, 12, 1000, startBlock)

    // 1,100 coins per block for asset 1
    await scoreMachine.setSpeedMock(asset1, 11, 100, startBlock)    
  })
  afterEach(async () => {
  })

  it("test close function", async function() {
    assert(close(1023, 1023))
    assert(close(10230000000000, 10230000000001))
    assert(close(10230000000002, 10230000000001))    
    assert(!close(10230000000002, 102300000000010))   
    assert(!close(102300000000020, 10230000000001))    
  })  

  it("check score increase after single user update balance", async function() {
    let block = startBlock + 123

    //updateScoreMock(bytes32 user, bytes32 asset, int96 dbalance, uint96 expectedBalance, uint32 blockNumber)    
    await scoreMachine.updateScoreMock(user0, asset0, 2005, 2005, block)
    const balance = await scoreMachine.getCurrentBalance(user0, asset0)
    assert.equal(balance.toString(), "2005")

    /*
    console.log("user data", await scoreMachine.getUserData(asset0, user0))
    console.log("global data", await scoreMachine.getGlobalData(asset0))
    console.log("distribution data", await scoreMachine.getDistributionData(asset0))
    */

    block += 100

    const indexDiff = await scoreMachine.calcScoreIndexDebug(asset0, block)
    const expectedIndexDiff = parseInt(12 * 1e10 * 100 / 2005)
    assert.equal(indexDiff.toString(), expectedIndexDiff.toString(), "unexpected index diff")

    const newScore = await scoreMachine.getScore(user0, asset0, block)
    assert(close(newScore, (12000 * 100 * 1e10)), "unexpected new score")
  })

  it("check single user that entered with previous balance", async function() {
    let block = startBlock + 123

    //updateScoreMock(bytes32 user, bytes32 asset, int96 dbalance, uint96 expectedBalance, uint32 blockNumber)    
    await scoreMachine.updateScoreMock(user0, asset0, 0, 2004, block)
    const balance = await scoreMachine.getCurrentBalance(user0, asset0)
    assert.equal(balance.toString(), "2004")

    block += 100

    const newScore = await scoreMachine.getScore(user0, asset0, block)
    assert(close(newScore, (12000 * 100 * 1e10)), "unexpected new score")
  })
  
  it("check two users with balance increase", async function() {
    let block = startBlock + 123

    //updateScoreMock(bytes32 user, bytes32 asset, int96 dbalance, uint96 expectedBalance, uint32 blockNumber)    
    await scoreMachine.updateScoreMock(user0, asset0, 1000, 1000, block)
    block += 100
    await scoreMachine.updateScoreMock(user1, asset0, 2000, 2000, block)
    block += 100

    const newScore0 = await scoreMachine.getScore(user0, asset0, block)
    const newScore1 = await scoreMachine.getScore(user1, asset0, block)

    /*
    console.log("user data 0", await scoreMachine.getUserData(asset0, user0))
    console.log("user data 1", await scoreMachine.getUserData(asset0, user1))

    console.log("global data", await scoreMachine.getGlobalData(asset0))
    */


    assert(close(newScore0, (12000 * 100 * 1e10 + 1 * 12000 * 100 * 1e10 / 3)), "unexpected new score0 " + newScore0.toString())
    assert(close(newScore1, (0                  + 2 * 12000 * 100 * 1e10 / 3)), "unexpected new score1 " + newScore1.toString())
  })
  
  it("check two users with external slash", async function() {
    let block = startBlock + 123

    //updateScoreMock(bytes32 user, bytes32 asset, int96 dbalance, uint96 expectedBalance, uint32 blockNumber)
    await scoreMachine.updateScoreMock(user0, asset0, 1000, 1000, block)
    block += 100
    await scoreMachine.updateScoreMock(user1, asset0, 2000, 2000, block)
    block += 100

    const newScore0 = await scoreMachine.getScore(user0, asset0, block)
    const newScore1 = await scoreMachine.getScore(user1, asset0, block)

    assert(close(newScore0, (12000 * 100 * 1e10 + 1 * 12000 * 100 * 1e10 / 3)), "unexpected new score0 " + newScore0.toString())
    assert(close(newScore1, (0                  + 2 * 12000 * 100 * 1e10 / 3)), "unexpected new score1 " + newScore1.toString())

    // slash first user for 100
    await scoreMachine.updateScoreMock(user0, asset0, 0, 900, block)

    const expectedSlashScore = newScore0.div(toBN(10))
    // 900/2900 of slashed score goes to user0, and 2000/2900 to user0
    const expectedScoreAfterSlash0 = newScore0.sub(expectedSlashScore).add(expectedSlashScore.mul(toBN(9)).div(toBN(29)))
    const expectedScoreAfterSlash1 = newScore1.add(expectedSlashScore.mul(toBN(20)).div(toBN(29)))

    const newScoreAfterSlash0 = await scoreMachine.getScore(user0, asset0, block)
    const newScoreAfterSlash1 = await scoreMachine.getScore(user1, asset0, block)

    assert(close(expectedScoreAfterSlash1, newScoreAfterSlash1), "unexpected score1 after slash")    
    assert(close(expectedScoreAfterSlash0, newScoreAfterSlash0), "unexpected score0 after slash")
  })

  it("check claim score", async function() {
    let block = startBlock + 123

    //updateScoreMock(bytes32 user, bytes32 asset, int96 dbalance, uint96 expectedBalance, uint32 blockNumber)
    await scoreMachine.updateScoreMock(user0, asset0, 1000, 1000, block)
    block += 100

    const newScore0 = await scoreMachine.getScore(user0, asset0, block)

    assert(close(newScore0, 12000 * 100 * 1e10), "unexpected new score0 " + newScore0.toString())

    let collectedScore = await scoreMachine.claimScoreMock.call(user0, asset0, 1000, block)
    await scoreMachine.claimScoreMock(user0, asset0, 1000, block)
    assert.equal(collectedScore.toString(), newScore0.toString(), "unexpected collected score")

    block += 200
    collectedScore = await scoreMachine.claimScoreMock.call(user0, asset0, 1000, block)
    await scoreMachine.claimScoreMock(user0, asset0, 1000, block)    
    assert.equal(collectedScore.toString(), newScore0.mul(toBN(2)).toString(), "unexpected collected score")

    collectedScore = await scoreMachine.claimScoreMock.call(user0, asset0, 1000, block)
    assert.equal(collectedScore.toString(), "0", "unexpected collected score")        
  })
  
  it("check total score", async function() {
    await scoreMachine.updateScoreMock(user0, asset0, 1000, 1000, startBlock)
    await scoreMachine.updateScoreMock(user1, asset0, 2000, 2000, startBlock)

    // 13k coins per block for asset 0
    await scoreMachine.setSpeedMock(asset0, 13, 1000, startBlock + 2)
    // 14k coins per block for asset 0
    await scoreMachine.setSpeedMock(asset0, 14, 1000, startBlock + 5)

    const totalScore = await scoreMachine.getGlobalScore(asset0, startBlock + 15)
    const expectedTotalScore = (12 * 2 + 13 * 3 + 14 * 10) * 1000 * 1e10

    assert.equal(totalScore.toString(), expectedTotalScore.toString(), "unexpected total score")
  })

  it("check two users with balance increase and decrease", async function() {
    let block = startBlock + 123

    //updateScoreMock(bytes32 user, bytes32 asset, int96 dbalance, uint96 expectedBalance, uint32 blockNumber)    
    await scoreMachine.updateScoreMock(user0, asset0, 2000, 2000, block)
    await scoreMachine.updateScoreMock(user1, asset0, 2000, 2000, block)

    block += 100

    let score0 = await scoreMachine.getScore(user0, asset0, block)
    let score1 = await scoreMachine.getScore(user1, asset0, block)

    assert(close(score0, 12000 * 100 * 1e10 / 2), "unexpected score0 " + score0.toString())
    assert(close(score1, 12000 * 100 * 1e10 / 2), "unexpected score1 " + score1.toString())

    await scoreMachine.updateScoreMock(user0, asset0, -1000, 1000, block)
    assert.equal((await scoreMachine.getCurrentBalance(user0, asset0)).toString(), "1000", "unexpected balance")

    block += 100

    score0 = await scoreMachine.getScore(user0, asset0, block)
    score1 = await scoreMachine.getScore(user1, asset0, block)

    assert(close(score1, 12000 * 100 * 1e10 / 2 + 2 * 12000 * 100 * 1e10 / 3), "unexpected score1 " + score1.toString())    
    assert(close(score0, 12000 * 100 * 1e10 / 2 + 1 * 12000 * 100 * 1e10 / 3), "unexpected score0 " + score0.toString())
    
  })  
})


function toBN(n) {
  return web3.utils.toBN(n)
}

function close(n1, n2) {
  const bigN1 = new web3.utils.toBN(n1)
  const bigN2 = new web3.utils.toBN(n2)

  const num = new web3.utils.toBN("1000001")
  const den = new web3.utils.toBN("1000000")

  if(bigN1.lt(bigN2)) return close(n2, n1)
  if(bigN1.mul(den).gt(bigN2.mul(num))) return false

  return true
}