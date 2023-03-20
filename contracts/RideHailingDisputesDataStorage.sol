// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RideHailingDisputesDataStorage {
    struct Dispute {
        address plaintiff;
        address defendant;
        string description;
        bool resolved;
    }
    Dispute[] private disputeData;

    constructor() {}

    function createDispute(
        address plaintiff,
        address defendant,
        string memory description
    ) public returns (uint256) {
        uint256 disputeId = disputeData.length;
        disputeData.push(Dispute(plaintiff, defendant, description, false));
        return disputeId;
    }
}
