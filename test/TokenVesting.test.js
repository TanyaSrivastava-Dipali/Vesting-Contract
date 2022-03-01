const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenVesting", function () {
  let Token;
  let testToken;
  let TokenVesting;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  before(async function () {
    Token = await ethers.getContractFactory("MyToken");
    TokenVesting = await ethers.getContractFactory("MockTokenVesting");
  });
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    testToken = await Token.deploy(100000000);
    await testToken.deployed();
  });

  describe("Vesting", () => {
    it("Should assign the total supply of tokens to the owner", async () => {
      const ownerBalance = await testToken.balanceOf(owner.address);
      expect(await testToken.totalSupply()).to.equal(ownerBalance);
    });
    it("Should vest tokens gradually - Advisers", async () => {
      const tokenVesting = await TokenVesting.deploy(testToken.address);
      expect((await tokenVesting.getToken()).toString()).to.equal(
        testToken.address
      );

      // send tokens to vesting contract
      await expect(testToken.transfer(tokenVesting.address, 100000000))
        .to.emit(testToken, "Transfer")
        .withArgs(owner.address, tokenVesting.address, 100000000);
      const vestingContractBalance = await testToken.balanceOf(
        tokenVesting.address
      );
      expect(vestingContractBalance).to.equal(100000000);

      await tokenVesting.setTGE(7, 5, 0);
      let tge = await tokenVesting.advisersAndPartnershipsTGE();
      tge = tge.toString();
      expect(tge).to.equal("7");
      await tokenVesting.calculatePools();
      let tgeBank = await tokenVesting.advisersAndPartnershipsTGEBank();
      tgeBank = tgeBank.toString();
      expect(tgeBank).to.equal("700000");
      let vestingPool = await tokenVesting.advisersAndPartnershipsVestingPool();
      vestingPool = vestingPool.toString();
      expect(vestingPool).to.equal("9300000");
      let withdrawable = await tokenVesting.getWithdrawableAmount();
      withdrawable = withdrawable.toString();
      expect(withdrawable).to.equal("80000000");

      let tgeForM = await tokenVesting.marketingTGE();
      tgeForM = tgeForM.toString();
      expect(tgeForM).to.equal("5");
      let tgeBankForM = await tokenVesting.marketingTGEBank();
      tgeBankForM = tgeBankForM.toString();
      expect(tgeBankForM).to.equal("300000");
      let vestingPoolForM = await tokenVesting.marketingVestingPool();
      vestingPoolForM = vestingPoolForM.toString();
      expect(vestingPoolForM).to.equal("5700000");

      let tgeForRF = await tokenVesting.reserveFundsTGE();
      tgeForRF = tgeForRF.toString();
      expect(tgeForRF).to.equal("0");
      let tgeBankForRF = await tokenVesting.reserveFundsTGEBank();
      tgeBankForRF = tgeBankForRF.toString();
      expect(tgeBankForRF).to.equal("0");
      let vestingPoolForRF = await tokenVesting.reserveFundsVestingPool();
      vestingPoolForRF = vestingPoolForRF.toString();
      expect(vestingPoolForRF).to.equal("4000000");

      const r = 0;
      const baseTime = 1622551248;
      const beneficiary = addr1;
      const startTime = baseTime;
      const cliff = 0;
      const duration = 1000;
      const slicePeriodSeconds = 1;
      const revokable = true;
      const amount = 100;

      await tokenVesting.createVestingSchedule(
        r,
        beneficiary.address,
        startTime,
        cliff,
        duration,
        slicePeriodSeconds,
        revokable,
        amount
      );
      expect(await tokenVesting.getVestingSchedulesCount()).to.be.equal(1);

      expect(
        await tokenVesting.getVestingSchedulesCountByBeneficiary(
          beneficiary.address
        )
      ).to.be.equal(1);
      const vestingScheduleId = await tokenVesting.getVestingIdAtIndex(0);

      // check that vested amount is 0
      expect(
        await tokenVesting.computeReleasableAmount(vestingScheduleId, 0)
      ).to.be.equal(0);

      const halfTime = baseTime + duration / 2;
      await tokenVesting.setCurrentTime(halfTime);

      expect(
        await tokenVesting
          .connect(beneficiary)
          .computeReleasableAmount(vestingScheduleId, r)
      ).to.be.equal(50);

      await expect(
        tokenVesting.connect(addr2).release(vestingScheduleId, 100, r)
      ).to.be.revertedWith(
        "TokenVesting: only beneficiary and owner can release vested tokens"
      );
      await expect(
        tokenVesting.connect(beneficiary).release(vestingScheduleId, 100, r)
      ).to.be.revertedWith(
        "TokenVesting: cannot release tokens, not enough vested tokens"
      );

      await expect(
        tokenVesting.connect(beneficiary).release(vestingScheduleId, 10, r)
      )
        .to.emit(testToken, "Transfer")
        .withArgs(tokenVesting.address, beneficiary.address, 10);
      expect(
        await tokenVesting
          .connect(beneficiary)
          .computeReleasableAmount(vestingScheduleId, r)
      ).to.be.equal(40);
      let vestingSchedule = await tokenVesting.getVestingSchedule(
        vestingScheduleId,
        r
      );
      expect(vestingSchedule.released).to.be.equal(10);
      await tokenVesting.setCurrentTime(baseTime + duration + 1);
      expect(
        await tokenVesting
          .connect(beneficiary)
          .computeReleasableAmount(vestingScheduleId, r)
      ).to.be.equal(90);
      await expect(
        tokenVesting.connect(beneficiary).release(vestingScheduleId, 45, r)
      )
        .to.emit(testToken, "Transfer")
        .withArgs(tokenVesting.address, beneficiary.address, 45);

      await expect(
        tokenVesting.connect(owner).release(vestingScheduleId, 45, r)
      )
        .to.emit(testToken, "Transfer")
        .withArgs(tokenVesting.address, beneficiary.address, 45);
      vestingSchedule = await tokenVesting.getVestingSchedule(
        vestingScheduleId,
        r
      );
      expect(vestingSchedule.released).to.be.equal(100);
      expect(
        await tokenVesting
          .connect(beneficiary)
          .computeReleasableAmount(vestingScheduleId, r)
      ).to.be.equal(0);
      await expect(
        tokenVesting.connect(addr2).revoke(vestingScheduleId, r)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await tokenVesting.revoke(vestingScheduleId, r);
      withdrawable = await tokenVesting.getWithdrawableAmount();
      withdrawable = withdrawable.toString();
      console.log("Withdrawable", withdrawable);
    });
    it("Should release vested tokens if revoked", async function () {
      // deploy vesting contract
      const tokenVesting = await TokenVesting.deploy(testToken.address);
      await tokenVesting.deployed();
      expect((await tokenVesting.getToken()).toString()).to.equal(
        testToken.address
      );
      // send tokens to vesting contract
      await expect(testToken.transfer(tokenVesting.address, 100000000))
        .to.emit(testToken, "Transfer")
        .withArgs(owner.address, tokenVesting.address, 100000000);

      const r = 0;
      const baseTime = 1622551248;
      const beneficiary = addr1;
      const startTime = baseTime;
      const cliff = 0;
      const duration = 1000;
      const slicePeriodSeconds = 1;
      const revokable = true;
      const amount = 100;

      // // create new vesting schedule

      await tokenVesting.setTGE(7, 5, 0);
      await tokenVesting.calculatePools();

      await tokenVesting.createVestingSchedule(
        r,
        beneficiary.address,
        startTime,
        cliff,
        duration,
        slicePeriodSeconds,
        revokable,
        amount
      );

      let withdrawable = await tokenVesting.getWithdrawableAmount();
      withdrawable = withdrawable.toString();
      console.log("Withdrawable", withdrawable);

      // // compute vesting schedule id
      const vestingScheduleId = await tokenVesting.getVestingIdAtIndex(0);

      // // set time to half the vesting period
      const halfTime = baseTime + duration / 2;
      await tokenVesting.setCurrentTime(halfTime);

      await expect(tokenVesting.revoke(vestingScheduleId, r))
        .to.emit(testToken, "Transfer")
        .withArgs(tokenVesting.address, beneficiary.address, 50);
    });
    it("Should compute vesting schedule index", async function () {
      const tokenVesting = await TokenVesting.deploy(testToken.address);
      await tokenVesting.deployed();
      const expectedVestingScheduleId =
        "0xa279197a1d7a4b7398aa0248e95b8fcc6cdfb43220ade05d01add9c5468ea097";
      expect(
        (
          await tokenVesting.computeVestingScheduleIdForAddressAndIndex(
            addr1.address,
            0
          )
        ).toString()
      ).to.equal(expectedVestingScheduleId);
      expect(
        (
          await tokenVesting.computeNextVestingScheduleIdForHolder(
            addr1.address
          )
        ).toString()
      ).to.equal(expectedVestingScheduleId);
    });
    it("Should check input parameters for createVestingSchedule method", async function () {
      const tokenVesting = await TokenVesting.deploy(testToken.address);
      await tokenVesting.deployed();
      await testToken.transfer(tokenVesting.address, 100000000);
      const time = Date.now();

      await tokenVesting.setTGE(7, 5, 0);
      await tokenVesting.calculatePools();

      await expect(
        tokenVesting.createVestingSchedule(
          0,
          addr1.address,
          time,
          0,
          0,
          1,
          false,
          1
        )
      ).to.be.revertedWith("TokenVesting: duration must be > 0");
      await expect(
        tokenVesting.createVestingSchedule(
          0,
          addr1.address,
          time,
          0,
          1,
          0,
          false,
          1
        )
      ).to.be.revertedWith("TokenVesting: slicePeriodSeconds must be >= 1");
      await expect(
        tokenVesting.createVestingSchedule(
          0,
          addr1.address,
          time,
          0,
          1,
          1,
          false,
          0
        )
      ).to.be.revertedWith("TokenVesting: amount must be > 0");
    });
    it("Can withdraw from TGEBank", async () => {
      const tokenVesting = await TokenVesting.deploy(testToken.address);
      await tokenVesting.deployed();
      await testToken.transfer(tokenVesting.address, 100000000);

      await tokenVesting.setTGE(7, 5, 0);
      await tokenVesting.calculatePools();

      const r = 0;
      const baseTime = 1622551248;
      const beneficiary = addr1;
      const startTime = baseTime;
      const cliff = 0;
      const duration = 1000;
      const slicePeriodSeconds = 1;
      const revokable = true;
      const amount = 100;

      await tokenVesting.createVestingSchedule(
        r,
        beneficiary.address,
        startTime,
        cliff,
        duration,
        slicePeriodSeconds,
        revokable,
        amount
      );
      let withdrawTGEBefore =
        await tokenVesting.advisersAndPartnershipsTGEBank();
      withdrawTGEBefore = withdrawTGEBefore.toString();
      console.log("Before value", withdrawTGEBefore);

      await tokenVesting.withdrawFromTGEBank(0, 10000);

      let withdrawTGEAfter =
        await tokenVesting.advisersAndPartnershipsTGEBank();
      withdrawTGEAfter = withdrawTGEAfter.toString();
      console.log("After value", withdrawTGEAfter);
      expect(parseInt(withdrawTGEAfter)).to.equal(
        parseInt(withdrawTGEBefore) - 10000
      );

      // expect(await tokenVesting.withdrawFromTGEBank(0, 100000000000)).to.be.revertedWith("You cannot withdraw this much");
      // expect(await tokenVesting.withdrawFromTGEBank(0, 100000000000)).eventually.to.rejectedWith(Error,"You cannot withdraw this much");
    });
  });
});
