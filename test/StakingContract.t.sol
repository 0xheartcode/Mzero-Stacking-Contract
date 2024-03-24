// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StakingContract.sol";
import "../src/BasicToken.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract StakingContractTest is Test {
    StakingContract stakingContract;
    BasicToken basicToken;

    address deployer = address(1);
    address staker1 = address(2);
    address staker2 = address(3);
    address staker3 = address(4);
    address staker4 = address(5);
    address staker5 = address(5);

    function setUp() public {
        // Define the addresses of the stakers
        address[] memory stakers = new address[](5);
        stakers[0] = staker1;
        stakers[1] = staker2;
        stakers[2] = staker3;
        stakers[3] = staker4;
        stakers[4] = staker5;

    
        // Deploy the BasicToken contract and mint tokens to the staker
        basicToken = new BasicToken();
        for (uint i = 0; i < stakers.length; i++) {
            basicToken.transfer(stakers[i], 100_000 * 1e18);
        }
        
        // Deploy the StakingContract with the BasicToken as the staking/reward token
        uint256 currentTime = block.timestamp;
        stakingContract = new StakingContract(basicToken, 1e18 /* Reward Rate */, currentTime /* Emission start */, 30 days /* Emission Duration */);
        basicToken.transfer(address(stakingContract), 10_000_000 * 1e18);

        // Approve the StakingContract to spend staker's tokens

        // Approve the StakingContract to spend stakers' tokens
        for (uint i = 0; i < stakers.length; i++) {
            vm.prank(stakers[i]);
            basicToken.approve(address(stakingContract), type(uint256).max);
        }

    }


    function testStakeAmount() public {
        // Simulate staker1 staking tokens
        vm.startPrank(staker1);
        stakingContract.stake(100 * 1e18);

        // Check if the staked amount is correctly recorded
        (uint256 amountStaked,,,) = stakingContract.stakers(staker1);
        assertEq(amountStaked, 100 * 1e18);

        stakingContract.stake(1 * 1e18);
        stakingContract.stake(2 * 1e18);
        stakingContract.stake(2 * 1e18);
        vm.stopPrank();

        vm.startPrank(staker2);
        stakingContract.stake(1 * 1e18);
        stakingContract.stake(2 * 1e18);
        (uint256 amountStakedStaker2,,,) = stakingContract.stakers(staker2);
        assertEq(amountStakedStaker2, 3 * 1e18);
        
        (uint256 amountStakedNext,,,) = stakingContract.stakers(staker1);
        assertEq(amountStakedNext, 105 * 1e18);

        vm.stopPrank();
    }


    function testStakeAndEarnRewards() public {
        // User1 stakes 10000 tokens
        vm.startPrank(staker1);
        stakingContract.stake(100 * 1e18);

        // Warp 1 week into the future
        vm.warp(block.timestamp + 1 days);

        // Claim rewards
        stakingContract.claimReward();

        // Check that user1's balance increased due to rewards
        assertTrue(basicToken.balanceOf(staker1) > 1000 * 1e18);
        vm.stopPrank();
    }


    /// @notice Test to measure the correct date of unstakes
    function testUnstakeWithTimelockDateCheck() public {
        vm.startPrank(staker1);
        stakingContract.stake(1 * 1e18);
        // Should fail, Cannot completeUnstake without initialUnstake first
        vm.expectRevert("Unstake not initiated");
        stakingContract.completeUnstake();
        
        // @dev single user linear unstake tests
        stakingContract.stake(100 * 1e18);

        // Initiate unstake
        stakingContract.initiateUnstake();
        (,,,uint256 unstakeInitTime) = stakingContract.stakers(staker1);
        assertEq(unstakeInitTime, block.timestamp);
 
        // Fail: early unstake attempt 
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();

        vm.expectRevert("Unstake already initiated");
        stakingContract.initiateUnstake();
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();

        console.log("Previous block timestamp:", block.timestamp);
        // Fail: early unstake attempt 
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();
        
        // Fail: early unstake attempt 
        vm.warp(block.timestamp + 5 days);
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();
        vm.stopPrank();
        
        vm.startPrank(staker2);
        stakingContract.stake(100 * 1e18);
        stakingContract.initiateUnstake();
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();
        vm.stopPrank();
       
        vm.startPrank(staker3);
        stakingContract.stake(100 * 1e18);
        stakingContract.initiateUnstake();
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();


        vm.stopPrank();


        vm.warp(block.timestamp + 1 days);

        vm.startPrank(staker2);
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();
        vm.stopPrank();
        vm.startPrank(staker3);
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();
        vm.stopPrank();


        vm.startPrank(staker1);
        // Success: unstake after waiting
        vm.warp(block.timestamp + stakingContract.getRemainingUnstakeTime(staker1));
        stakingContract.completeUnstake();
        vm.stopPrank();
        vm.startPrank(staker2);
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();
        vm.stopPrank();
        vm.startPrank(staker3);
        vm.expectRevert("Timelock not yet passed");
        stakingContract.completeUnstake();
        vm.stopPrank();

        vm.warp(block.timestamp + stakingContract.getRemainingUnstakeTime(staker3));
        vm.startPrank(staker2);
        stakingContract.completeUnstake();
        vm.stopPrank();
        vm.startPrank(staker3);
        (,,,uint256 unstakeInitTimePretUnstakeStaker3) = stakingContract.stakers(staker3);
        assertGe(unstakeInitTimePretUnstakeStaker3, 0);
        stakingContract.completeUnstake();
        (,,,uint256 unstakeInitTimePostUnstakeStaker3) = stakingContract.stakers(staker3);
        assertEq(unstakeInitTimePostUnstakeStaker3, 0);

        // @dev Unstake and change unstake time from dev:


        vm.stopPrank();
    }

    /// @notice Test to measure the correct balance after `completeUnstake()`
    function testUnstakeWithTimelockBalanceCheck() public {
    }

    /// @notice Test admin change Fees
    function testAdminChangeUnstakeFees() private {
        //vm.startPrank(deployer);
        stakingContract.setUnstakeFeePercent(100); 
        assertEq(stakingContract.unstakeFeePercent(), 100, "Fee not updated correctly to 1%.");
        
        stakingContract.setUnstakeFeePercent(1);
        assertEq(stakingContract.unstakeFeePercent(), 1, "Fee not updated correctly to 0,01%.");
        
        stakingContract.setUnstakeFeePercent(0);
        assertEq(stakingContract.unstakeFeePercent(), 0, "Fee not updated correctly to 2%.");

        stakingContract.setUnstakeFeePercent(200); 
        assertEq(stakingContract.unstakeFeePercent(), 200, "Fee not updated correctly to 2%.");
          
        // Fail; Value too high
        vm.expectRevert("Unstake fee exceeds 2%, maximum allowed");
        stakingContract.setUnstakeFeePercent(600);

        // Check if it reverts on non-owner calls.
        vm.startPrank(staker1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, staker1));
        stakingContract.setUnstakeFeePercent(100); 
        vm.stopPrank();
    }

    function testAdminChangeTimelockDate() public {
        //vm.startPrank(deployer);
        stakingContract.setUnstakeTimeLock(2 days);
        assertEq(stakingContract.unstakeTimeLock(), 2 days, "Timelock end time not updated correctly.");
        stakingContract.setUnstakeTimeLock(5 days);
        assertEq(stakingContract.unstakeTimeLock(), 5 days, "Timelock end time not updated correctly.");
        stakingContract.setUnstakeTimeLock(15 days);
        assertEq(stakingContract.unstakeTimeLock(), 15 days, "Timelock end time not updated correctly.");
        vm.expectRevert("Time lock must be between 0 to 15 days");
        stakingContract.setUnstakeTimeLock(20 days);
        //vm.stopPrank();

        // Check if it reverts on non owner calls.
        vm.startPrank(staker1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector,staker1));
        stakingContract.setUnstakeTimeLock(1 days);
        vm.stopPrank();
    }
}

