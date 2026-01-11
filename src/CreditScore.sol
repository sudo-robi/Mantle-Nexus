// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title On-Chain Credit Scoring Layer
/// @notice Manages user-specific Loan-to-Value (LTV) ratios based on ZK Attestations
contract CreditScore is Ownable {

    error InvalidLTV();
    error Unauthorized();

    uint256 public constant DEFAULT_LTV = 50;
    uint256 public constant MAX_LTV = 80; 
    mapping(address => uint256) public userApprovedLTV;
    address public zkAttestationUpdater;
    event LTVUpdated(address indexed user, uint256 newLTV);
    constructor(address _owner) Ownable(_owner) {}
    /// @notice Retrieves the LTV percentage (e.g., 50, 60) for a given user.
    /// @dev This is the function the MCRWAVault will call before a borrow operation.
    /// @param user The address of the borrower.
    /// @return The approved LTV percentage.
    function getAdjustedLTV(address user) external view returns (uint256) {
        if (userApprovedLTV[user] > 0) {
            return userApprovedLTV[user];
        }
        return DEFAULT_LTV;
    }

    /// @notice Sets the address of the trusted entity that can update scores.
    function setZKAttestationUpdater(address _updater) external onlyOwner {
        zkAttestationUpdater = _updater;
    }
    /// @notice Function called by the ZK Attestation Updater to set a user's LTV.
    /// @dev In a full ZK implementation, this function's modifier would be a ZK Verifier.
    function updateLTV(address user, uint256 newLTV) external {
        if (msg.sender != zkAttestationUpdater) revert Unauthorized();
        if (newLTV < DEFAULT_LTV || newLTV > MAX_LTV) revert InvalidLTV();

        userApprovedLTV[user] = newLTV;
        emit LTVUpdated(user, newLTV);
    }
}