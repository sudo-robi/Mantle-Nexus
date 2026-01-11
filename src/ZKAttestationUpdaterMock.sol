// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CreditScore.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ZK Attestation Updater (Mock)
/// @notice Simulates a ZK-proof verifier / off-chain credit attestation service
/// @dev In production, this would verify a ZK proof before updating the credit score
contract ZKAttestationUpdaterMock is Ownable {

    CreditScore public creditScore;

    event CreditAttested(address indexed user, uint256 newLTV);

    constructor(address _creditScore) Ownable(msg.sender) {
        require(_creditScore != address(0), "Invalid CreditScore address");
        creditScore = CreditScore(_creditScore);
    }

    /// @notice Simulates a successful ZK credit attestation
    /// @dev In production, this function would:
    /// 1. Verify a ZK proof
    /// 2. Derive a credit score
    /// 3. Update the user's LTV

    function attestCredit(address user, uint256 newLTV) external onlyOwner {
        creditScore.updateLTV(user, newLTV);
        emit CreditAttested(user, newLTV);
    }
    function configureAttester() external onlyOwner {
    creditScore.setZKAttestationUpdater(address(this));
}
}
