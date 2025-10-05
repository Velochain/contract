// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IX2EarnRewardsPool} from "./interfaces/IX2EarnRewardsPool.sol";

// 0x9B9CA9D0C41Add1d204f90BA0E9a6844f1843A84

contract Cycle2earn {
    struct Reward {
        uint256 totalAmount; // total amount of rewards
        uint256 claimedAmount; // amount of rewards claimed
    }

    address public verifier;

    IX2EarnRewardsPool x2EarnRewardsPool;
    bytes32 private VBD_APP_ID;

    mapping(string => address) public stravaIdToAddress;
    mapping(address => string) public addressToStravaId;

    mapping(address => string[]) private userClaimedCycles;
    mapping(address => Reward) private userRewards;

    // events
    event RewardAdded(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event StravaConnected(address indexed user, string stravaId);

    // errors
    error InvalidSignature(address recoveredAddress, ECDSA.RecoverError error);
    error StravaIdAlreadyConnected();
    error InvalidAmount();

    // constructor() {
    //     verifier = msg.sender;
    // }

    constructor(
        IX2EarnRewardsPool _x2EarnRewardsPool,
        bytes32 _VBD_APP_ID,
        address _verifier
    ) {
        x2EarnRewardsPool = _x2EarnRewardsPool;
        VBD_APP_ID = _VBD_APP_ID;
        verifier = _verifier;
    }

    /**
     * @notice Connects a Strava ID to the user's address
     * @param stravaId The Strava ID to connect
     */
    function connectStrava(string memory stravaId) public {
        require(
            stravaIdToAddress[stravaId] == address(0),
            "StravaIdAlreadyConnected"
        );
        stravaIdToAddress[stravaId] = msg.sender;
        addressToStravaId[msg.sender] = stravaId;
    }

    /**
     * @notice Gets the Strava ID for a user
     * @param user The address of the user
     * @return The Strava ID
     */
    function getUserStravaId(address user) public view returns (string memory) {
        return addressToStravaId[user];
    }

    /**
     * @notice Gets the rewards for a user
     * @param user The address of the user
     * @return The rewards
     */
    function getUserRewards(address user) public view returns (Reward memory) {
        return userRewards[user];
    }

    /**
     * @notice Adds a reward to a user
     * @param user The address of the user
     * @param amount The amount of rewards to add
     */
    function addReward(
        address user,
        uint256 amount,
        bytes memory signature
    ) external {
        bytes memory message = getRewardHash(user, amount);
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(message);
        (
            bool isValid,
            address recoveredAddress,
            ECDSA.RecoverError returnedError
        ) = isValidSignature(messageHash, signature);
        if (!isValid) {
            revert InvalidSignature(recoveredAddress, returnedError);
        }
        userRewards[user].totalAmount += amount;
    }

    /**
     * @notice Adds a reward to a user from the backend without user signing the message
     * @param user The address of the user
     * @param amount The amount of rewards to add
     */
    function addRewardAlt(address user, uint256 amount) external {
        require(msg.sender == verifier, "InvalidSender");
        userRewards[user].totalAmount += amount;
    }

    function isValidSignature(
        bytes32 messageHash,
        bytes memory signature
    ) internal view returns (bool, address, ECDSA.RecoverError) {
        (address recoveredAddress, ECDSA.RecoverError returnedError, ) = ECDSA
            .tryRecover(messageHash, signature);

        if (returnedError != ECDSA.RecoverError.NoError) {
            return (false, recoveredAddress, returnedError);
        }

        return (recoveredAddress == verifier, recoveredAddress, returnedError);
    }

    function getRewardHash(
        address user,
        uint256 amount
    ) public pure returns (bytes memory message) {
        message = bytes.concat(bytes20(user), abi.encodePacked(amount));
    }

    function claimReward(address user) public {
        Reward memory userReward = userRewards[user];
        uint256 amountToClaim = userReward.totalAmount -
            userReward.claimedAmount;
        require(amountToClaim > 0, "InvalidAmount");
        userReward.claimedAmount += amountToClaim;
        userRewards[user] = userReward;
        x2EarnRewardsPool.distributeReward(
            VBD_APP_ID,
            amountToClaim,
            msg.sender, // this is the user calling the claimReward function
            "" // proof and impacts not provided
        );
    }
}
