const Token = artifacts.require("Token");
const Recipient = artifacts.require("Recipient")
const { assertRevert } = require('@aragon/test-helpers/assertThrow')

contract('Token', (accounts) => {

  let token;
  let amount = 10000;

  context('transferable token', async () => {

    beforeEach(async () => {
        token = await Token.new('n', 0, 'n', true)
    })

    it('first account is controller', async () => {

      let controller = await token.controller()

      assert.equal(controller, accounts[0], "token controller wasn't first account");
    });

    it('controller can mint', async () => {
      await token.generateTokens(accounts[0], amount)
      let supply = await token.totalSupply()
      let balance = await token.balanceOf(accounts[0])

      assert.equal(supply.valueOf(), amount, "10000 wasn't the total supply");
      assert.equal(balance.valueOf(), amount, "10000 wasn't in the first account");
    });

    it('non-controller cannot mint', async () => {
      return assertRevert(async () => {
        await token.generateTokens(accounts[1], amount, {from: accounts[1]})
      })
    });

    it('normal transfer succeeds', async () => {
      let moveAmount = 5000;

      await token.generateTokens(accounts[0], amount)
      await token.transfer(accounts[1], moveAmount, {from: accounts[0]})
      await token.transfer(accounts[2], moveAmount, {from: accounts[1]})
      let balance1 = await token.balanceOf(accounts[1])
      let balance2 = await token.balanceOf(accounts[2])

      assert.equal(balance1.valueOf(), 0, "0 wasn't in the second account");
      assert.equal(balance2.valueOf(), moveAmount, "5000 wasn't in the third account");
    });

    it('Should allow and transfer tokens from address 2 to address 1 allowed to 3', async () => {
      await token.generateTokens(accounts[2], amount)

      await token.approve(accounts[3], 2, { from: accounts[2] });
      const allowed = await token.allowance(accounts[2], accounts[3]);
      assert.equal(allowed, 2);

      await token.transferFrom(accounts[2], accounts[1], 1, { from: accounts[3] });

      const allowed2 = await token.allowance(accounts[2], accounts[3]);
      assert.equal(allowed2, 1);
    });

    it('controller cannot transferFrom without allowance', async () => {
      let moveAmount = 5000;
      await token.generateTokens(accounts[1], amount)

      return assertRevert(async () => {
        await token.transferFrom(accounts[1], accounts[2], moveAmount)
      })
    });

    it('send', async () => {
      let moveAmount = 5000;
      await token.generateTokens(accounts[0], amount)

      let recipient = await Recipient.new()

      await token.send(recipient.address, moveAmount, "0x")

      let balance = await token.balanceOf(recipient.address)

      assert.equal(balance.valueOf(), moveAmount, `${moveAmount} wasn't in the recipient account`);
    });

  })

  context('non-transferable token', async () => {

    beforeEach(async () => {
        token = await Token.new('n', 0, 'n', false)
    })

    it('controller can mint', async () => {
      await token.generateTokens(accounts[0], amount)
      let supply = await token.totalSupply()
      let balance = await token.balanceOf(accounts[0])

      assert.equal(supply.valueOf(), amount, "10000 wasn't the total supply");
      assert.equal(balance.valueOf(), amount, "10000 wasn't in the first account");
    });

    it('controller can still transfer non-transferable', async () => {
      await token.generateTokens(accounts[0], amount)
      await token.transfer(accounts[1], amount, {from: accounts[0]})
      let balance = await token.balanceOf(accounts[1])

      assert.equal(balance.valueOf(), amount, "10000 wasn't the total supply");
    });

    it('normal transfer fails', async () => {
      await token.generateTokens(accounts[1], amount)

      return assertRevert(async () => {
        await token.transfer(accounts[2], amount, {from: accounts[1]})
      })
    });

  })

});
