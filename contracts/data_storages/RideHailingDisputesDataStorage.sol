// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingDisputesDataStorage is DataStorageBaseContract {
    struct Dispute {
        address plaintiff;
        address defendant;
        string description;
        string replyDescription;
        bool resolved;
        uint256 plaintiffVotes;
        uint256 defendantVotes;
        address [] voterList; //only one person can vote once
    }
    Dispute[] private disputeData;

    function createDispute(
        address plaintiff,
        address defendant,
        string calldata description
    ) external internalContractsOnly returns (uint256) {
        uint256 disputeId = disputeData.length;
        disputeData.push(Dispute(plaintiff, defendant, description, "", false, 0, 0, new address [] (0)));
        return disputeId;
    }

    function getDispute(uint256 disputeId) external view internalContractsOnly returns(Dispute memory) {
        return disputeData[disputeId];
    }

    function setPlaintiffDescription(uint256 disputeId, string calldata replyDescription) external internalContractsOnly {
        disputeData[disputeId].replyDescription = replyDescription;
    }

    function increasePlaintiffVotes(uint256 disputeId) external internalContractsOnly {
        disputeData[disputeId].plaintiffVotes++;
    }

    function increaseDefendantVotes(uint256 disputeId) external internalContractsOnly {
        disputeData[disputeId].defendantVotes++;
    }

    function getDefendant(uint256 disputeId) external view internalContractsOnly returns (address) {
        return disputeData[disputeId].defendant;
    }

    function checkDisputeExist(uint256 disputeId) external view internalContractsOnly returns (bool) {
        if(disputeId > disputeData.length) {
            return false;
        } else {
            return true;
        }
    }
}
