// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingDisputesDataStorage is DataStorageBaseContract {
    struct Dispute {
        address plaintiff;
        address defendant;
        string description;
        bool resolved;
    }
    Dispute[] private disputeData;

    constructor(address ownerAddress) DataStorageBaseContract(ownerAddress) {}

    function createDispute(
        address plaintiff,
        address defendant,
        string calldata description
    ) external internalContractsOnly returns (uint256) {
        uint256 disputeId = disputeData.length;
        disputeData.push(Dispute(plaintiff, defendant, description, false));
        return disputeId;
    }
}
