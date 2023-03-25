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
        uint256 [] voterChoice;
        address [] voterWinners;
    }
    Dispute[] private disputeData;

    function createDispute(
        address plaintiff,
        address defendant,
        string calldata description
    ) external internalContractsOnly returns (uint256) {
        uint256 disputeId = disputeData.length;
        disputeData.push(Dispute(plaintiff, defendant, description, "", false, 0, 0, new address [] (0), new uint256 [] (0), new address [] (0) ));
        return disputeId;
    }

    function getDispute(uint256 disputeId) external view internalContractsOnly returns(Dispute memory) {
        return disputeData[disputeId];
    }

    function setPlaintiffDescription(uint256 disputeId, string calldata replyDescription) external internalContractsOnly {
        disputeData[disputeId].replyDescription = replyDescription;
    }

    function increasePlaintiffVotes(uint256 disputeId, address voter) external internalContractsOnly {
        disputeData[disputeId].plaintiffVotes++;
        disputeData[disputeId].voterChoice.push(1); // 1 means vote for plaintiff
        disputeData[disputeId].voterList.push(voter);
    }

    function increaseDefendantVotes(uint256 disputeId, address voter) external internalContractsOnly {
        disputeData[disputeId].defendantVotes++;
        disputeData[disputeId].voterChoice.push(2); // 2 means vote for defendant
        disputeData[disputeId].voterList.push(voter);
    }

    function getPlaintiffVotes(uint256 disputeId) external view internalContractsOnly returns (uint256) {
        return disputeData[disputeId].plaintiffVotes;
    }

    function getDefendantVotes(uint256 disputeId) external view internalContractsOnly returns (uint256) {
        return disputeData[disputeId].defendantVotes;
    }


    function getDefendant(uint256 disputeId) external view internalContractsOnly returns (address) {
        return disputeData[disputeId].defendant;
    }

    function getPlaintiff(uint256 disputeId) external view internalContractsOnly returns (address) {
        return disputeData[disputeId].plaintiff;
    }

    function checkDisputeExist(uint256 disputeId) external view internalContractsOnly returns (bool) {
        if(disputeId > disputeData.length) {
            return false;
        } else {
            return true;
        }
    }

    function won(uint256 disputeId, uint256 winner) external internalContractsOnly returns (address[] memory) {
        uint256 [] memory voterChoiceFinal = disputeData[disputeId].voterChoice;
        for(uint256 i = 0; i <= voterChoiceFinal.length; i++) {
            if(voterChoiceFinal[i] == winner) {
                disputeData[disputeId].voterWinners.push(disputeData[disputeId].voterList[i]);
            }
        }
        return disputeData[disputeId].voterWinners;
    }
}
