// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is ReentrancyGuard, Ownable {
    IERC20 public basicToken;
    uint256 public totalStaked;
    uint256 public emissionRate;
    uint256 public emissionStart;
    uint256 public emissionEnd;
    uint256 public unstakeTimeLock = 15 days;
    uint256 public unstakeFeePercent = 0; // Default 0%, can be raised up to 2%

    struct Staker {
        uint256 amountStaked;
        uint256 stakeTime;
        uint256 lastClaimTime;
        uint256 unstakeInitTime;
    }

    mapping(address => Staker) public stakers;

    event Staked(address indexed user, uint256 amount);
    event UnstakeInit(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);



    constructor() Ownable(msg.sender){
        basicToken = IERC20(0x9ebD35D76449830342C5b1dbA9563979B21e41cB);
        emissionRate = 10;
        emissionStart = block.timestamp;
        emissionEnd = emissionStart + 10000;
    }

//    constructor(IERC20 _basicToken, uint256 _emissionRate, uint256 _duration) {
//        basicToken = _basicToken;
//        emissionRate = _emissionRate;
//        emissionStart = block.timestamp;
//        emissionEnd = emissionStart + _duration;
//    }

    function stake(uint256 _amount) external nonReentrant {
        require(block.timestamp < emissionEnd, "Staking period has ended");
        require(staker.unstakeInitTime == 0, "Unstake in progress. Must complete or cancel unstake.");
        require(_amount > 0, "Amount must be greater than 0");
        
        require(basicToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        Staker storage staker = stakers[msg.sender];
        staker.amountStaked += _amount;
        staker.stakeTime = block.timestamp;
        staker.lastClaimTime = block.timestamp;

        totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    function initiateUnstake() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.amountStaked > 0, "No tokens staked");
        staker.unstakeInitTime = block.timestamp;

        emit UnstakeInitiated(msg.sender, staker.amountStaked);
    }

    function completeUnstake() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.amountStaked > 0, "No tokens staked");
        require(block.timestamp >= staker.unstakeInitTime + unstakeTimeLock, "Timelock period not yet passed");

        uint256 reward = calculateReward(msg.sender);
        uint256 amount = staker.amountStaked;
        // Higher precision fee
        uint256 fee = (amount * unstakeFeePercent * 1e4) / (100 * 1e4);
        uint256 amountAfterFee = amount - fee;
        uint256 amountAfterFeeAndReward = amountAfterFee + reward;

        // Reset staker information
        totalStaked -= amount;
        delete stakers[msg.sender];
        
        // Transfer unstaked amount minus fee plus rewards
        require(basicToken.transfer(msg.sender, amountAfterFeeAndReward), "Transfer failed");
        emit Unstaked(msg.sender, amountAfterFeeAndReward, reward);
    }


    function calculateReward(address _staker) public view returns (uint256) {
        Staker storage staker = stakers[_staker];
        uint256 lastEmissionTimestamp = block.timestamp > emissionEnd ? emissionEnd : block.timestamp;
        
        if (staker.amountStaked > 0 && staker.lastClaimTime < lastEmissionTimestamp) {
            // Calculate the staking duration considering the emission end
            uint256 stakingDuration = lastEmissionTimestamp - staker.lastClaimTime;
            
            // Total rewards that would be distributed to all stakers in this duration
            uint256 totalRewardsForDuration = stakingDuration * emissionRate;
            
            // Calculate staker's share of the total staked amount
            // Using a large scaling factor to maintain precision
            uint256 stakerShare = (staker.amountStaked * 1e18) / totalStaked;
            
            // Calculate the staker's reward based on their share
            // Scaling down the reward to the correct magnitude after multiplication
            uint256 reward = (totalRewardsForDuration * stakerShare) / 1e18;
            
            return reward;
        } else {
            return 0;
        }
    }

    function setUnstakeFeePercent(uint256 _newFee) external onlyOwner {
        require(_newFee <= 2, "Normal unstake fee exceeds 2%, maximum allowed");
        unstakeFeePercent = _newFee;
    }

    function setUnstakeTimeLock(uint256 _newTimeLock) external onlyOwner {
        require(_newTimeLock <= 15 days, "Time lock must be between 0 to 15 days");
        unstakeTimeLock = _newTimeLock;
    }

    function getRemainingUnstakeTime(address _staker) external view returns (uint256) {
        Staker storage staker = stakers[_staker];
        if (block.timestamp < staker.unstakeInitTime + unstakeTimeLock) {
            return (staker.unstakeInitTime + unstakeTimeLock) - block.timestamp;
        } else {
            return 0;
        }
    }


}

