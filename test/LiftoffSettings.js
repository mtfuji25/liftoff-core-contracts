// test/Box.js
// Load dependencies
const { UpgradesError } = require('@openzeppelin/upgrades-core/dist/error');
const { expect } = require('chai');
 
let Box;
let box;
 
// Start test block
describe('LiftoffSettings', function () {
  beforeEach(async function () {
    LiftoffSettings = await ethers.getContractFactory("LiftoffSettings");
    liftoffSettings = await upgrades.deployProxy(LiftoffSettings);// add initializer here eg .deployProxy(Box, [42], {initializer: 'store'});
  });
 
  // Test case
  it('retrieve returns a value previously stored', async function () {
    // Store a value
    //await box.store(42);
 
    // Test if the returned value is the same one
    // Note that we need to use strings to compare the 256 bit integers
    //expect((await box.retrieve()).toString()).to.equal('42');
  });
});