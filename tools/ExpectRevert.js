const { expect } = require('chai');
module.exports.expectRevert = async (promise, message) => {
  let result = "";
  try{
    await promise;
    result = "Method did not revert.";
  } catch (e) {
    result = e.message.substr(50);
  }
  expect(message).to.eq(result);
}