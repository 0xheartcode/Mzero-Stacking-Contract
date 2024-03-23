// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StakingContract.sol";
import "../src/BasicToken.sol";

contract StakingContractTest is Test {
    StakingContract stakingContract;
    BasicToken basicToken;

    address deployer = address(1);
    address staker1 = address(2);

    function setUp() public {
        // Deploy the BasicToken contract and mint tokens to the staker
        basicToken = new BasicToken();
        basicToken.transfer(staker1, 100_000 * 1e18);

        // Deploy the StakingContract with the BasicToken as the staking/reward token
        stakingContract = new StakingContract(basicToken, 1e18 /* Reward Rate */, 30 days /* Emission Duration */);

        // Approve the StakingContract to spend staker's tokens
        vm.prank(staker1);
        basicToken.approve(address(stakingContract), type(uint256).max);
    }

    function testStake() public {
        // Simulate staker1 staking tokens
        vm.startPrank(staker1);
        stakingContract.stake(100 * 1e18);
        vm.stopPrank();

        // Check if the staked amount is correctly recorded
        (uint256 amountStaked,,,) = stakingContract.stakers(staker1);
        assertEq(amountStaked, 100 * 1e18);
    }

    function testStakeAndEarnRewards() public {
        // User1 stakes 10000 tokens
        vm.startPrank(staker1);
        stakingContract.stake(100 * 1e18);

        // Warp 1 week into the future
        vm.warp(block.timestamp + 1 weeks);

        // Claim rewards
        stakingContract.claimReward();

        // Check that user1's balance increased due to rewards
        assertTrue(basicToken.balanceOf(staker1) > 1000 * 1e18);
        vm.stopPrank();
    }

    function testUnstakeWithTimelock() public {
        vm.startPrank(staker1);
        stakingContract.stake(100 * 1e18);

        // Initiate unstake
        stakingContract.initiateUnstake();

        // Attempt to complete unstake before timelock expires should fail
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();

        // Warp past the unstake timelock
        vm.warp(block.timestamp + stakingContract.unstakeTimeLock());

        // Complete unstake successfully
        stakingContract.completeUnstake();
        vm.stopPrank();
    }
    // Add more tests here...
}

