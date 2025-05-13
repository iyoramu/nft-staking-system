// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTStaking is ReentrancyGuard, Ownable {
    // Struct to store stake information
    struct Stake {
        uint256 tokenId;
        uint256 stakedAt;
        address owner;
    }

    // Reward token and NFT contract interfaces
    IERC20 public rewardToken;
    IERC721 public nftCollection;

    // Mapping from tokenId to stake
    mapping(uint256 => Stake) public stakes;

    // Reward rate per NFT per second
    uint256 public rewardRatePerSecond;

    // Total NFTs staked
    uint256 public totalStaked;

    // Events
    event NFTStaked(address indexed owner, uint256 tokenId, uint256 stakedAt);
    event NFTUnstaked(address indexed owner, uint256 tokenId, uint256 unstakedAt);
    event RewardClaimed(address indexed owner, uint256 amount);

    constructor(
        address _nftCollection,
        address _rewardToken,
        uint256 _rewardRatePerDay
    ) Ownable(msg.sender) {
        nftCollection = IERC721(_nftCollection);
        rewardToken = IERC20(_rewardToken);
        rewardRatePerSecond = _rewardRatePerDay / 86400; // Convert daily rate to per second
    }

    // Stake NFTs
    function stake(uint256[] calldata tokenIds) external nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(nftCollection.ownerOf(tokenId) == msg.sender, "Not the owner");
            require(stakes[tokenId].stakedAt == 0, "Already staked");

            nftCollection.transferFrom(msg.sender, address(this), tokenId);
            stakes[tokenId] = Stake({
                tokenId: tokenId,
                stakedAt: block.timestamp,
                owner: msg.sender
            });

            emit NFTStaked(msg.sender, tokenId, block.timestamp);
        }
        totalStaked += tokenIds.length;
    }

    // Unstake NFTs and claim rewards
    function unstake(uint256[] calldata tokenIds) external nonReentrant {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            Stake memory stakeInfo = stakes[tokenId];
            require(stakeInfo.owner == msg.sender, "Not the owner");

            totalRewards += calculateReward(tokenId);
            delete stakes[tokenId];
            nftCollection.transferFrom(address(this), msg.sender, tokenId);

            emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
        }
        totalStaked -= tokenIds.length;

        if (totalRewards > 0) {
            rewardToken.transfer(msg.sender, totalRewards);
            emit RewardClaimed(msg.sender, totalRewards);
        }
    }

    // Claim rewards without unstaking
    function claimRewards(uint256[] calldata tokenIds) external nonReentrant {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(stakes[tokenId].owner == msg.sender, "Not the owner");

            totalRewards += calculateReward(tokenId);
            stakes[tokenId].stakedAt = block.timestamp; // Reset stake time
        }

        require(totalRewards > 0, "No rewards");
        rewardToken.transfer(msg.sender, totalRewards);
        emit RewardClaimed(msg.sender, totalRewards);
    }

    // Calculate reward for a single NFT
    function calculateReward(uint256 tokenId) public view returns (uint256) {
        Stake memory stakeInfo = stakes[tokenId];
        if (stakeInfo.stakedAt == 0) return 0;

        uint256 stakedDuration = block.timestamp - stakeInfo.stakedAt;
        return stakedDuration * rewardRatePerSecond;
    }

    // Get all staked NFTs for a user
    function getUserStakes(address user) external view returns (Stake[] memory) {
        uint256[] memory tokenIds = new uint256[](totalStaked);
        uint256 count = 0;
        
        // In a real implementation, we'd use an enumerable NFT or maintain a separate array
        // This is simplified for demonstration
        for (uint256 i = 0; i < 10000; i++) {
            if (stakes[i].owner == user) {
                tokenIds[count] = i;
                count++;
            }
        }
        
        Stake[] memory userStakes = new Stake[](count);
        for (uint256 i = 0; i < count; i++) {
            userStakes[i] = stakes[tokenIds[i]];
        }
        
        return userStakes;
    }

    // Admin functions
    function updateRewardRate(uint256 newRatePerDay) external onlyOwner {
        rewardRatePerSecond = newRatePerDay / 86400;
    }

    function emergencyWithdraw() external onlyOwner {
        rewardToken.transfer(owner(), rewardToken.balanceOf(address(this)));
    }
}
