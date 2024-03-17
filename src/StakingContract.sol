// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is ReentrancyGuard, Ownable {
    IERC20 public basicToken;
    uint256 public totalStaked;
    uint256 public emissionRate; // Tokens emitted per second since last claim
    uint256 public emissionStart;
    uint256 public emissionEnd;
    uint256 public constant unstakeTimeLock = 14 days;
    uint256 public unstakeFeePercent = 0; // Default 0%, can be raised up to 5%
    uint256 public emergencyUnstakeFeePercent = 5; // Emergency unstake fee starts at 5%

    struct Staker {
        uint256 amountStaked;
        uint256 stakeTime;
        uint256 lastClaimTime;
        uint256 unstakeInitTime;
        uint256 rewardDebt; // Amount of rewards claimed
    }

    mapping(address => Staker) public stakers;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event EmergencyUnstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

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
    }

    function completeUnstake() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.amountStaked > 0, "No tokens staked");
        require(block.timestamp >= staker.unstakeInitTime + unstakeTimeLock, "Timelock period not yet passed");

        uint256 reward = calculateReward(msg.sender);
        uint256 amount = staker.amountStaked;
        uint256 fee = amount * unstakeFeePercent / 100;
        uint256 amountAfterFee = amount - fee;
        uint256 amountAfterReward = amountAfterFee + reward;

        // Reset staker information
        staker.amountStaked = 0;
        staker.rewardDebt = 0;

        // Transfer unstaked amount minus fee and rewards
        require(basicToken.transfer(msg.sender, amountAfterReward), "Transfer failed");
        emit Unstaked(msg.sender, amountAfterFee, reward);
    }

    function emergencyUnstake() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.amountStaked > 0, "No tokens staked");

        uint256 amount = staker.amountStaked;
        uint256 fee = amount * emergencyUnstakeFeePercent / 100;
        uint256 amountAfterFee = amount - fee;

        staker.amountStaked = 0;
        staker.rewardDebt = 0; // Forfeit all rewards

        require(basicToken.transfer(msg.sender, amountAfterFee), "Transfer failed");
        emit EmergencyUnstaked(msg.sender, amountAfterFee);
    }

    function calculateReward(address _staker) public view returns (uint256) {
        Staker storage staker = stakers[_staker];
        if (block.timestamp > staker.lastClaimTime && staker.amountStaked > 0) {
            uint256 stakingDuration = block.timestamp - staker.lastClaimTime;
            uint256 rewardRatePerToken = emissionRate;
            uint256 reward = stakingDuration * staker.amountStaked * rewardRatePerToken;
            return reward;
        } else {
            return 0;
        }
    }


    function setUnstakeFeePercent(uint256 _newFee) external onlyOwner {
        require(_newFee <= 5, "Normal unstake fee exceeds maximum allowed");
        unstakeFeePercent = _newFee;
    }

    function setEmergencyUnstakeFeePercent(uint256 _newFee) external onlyOwner {
        require(_newFee >= 5 && _newFee <= 10, "Emergency unstake fee out of bounds");
        emergencyUnstakeFeePercent = _newFee;
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

