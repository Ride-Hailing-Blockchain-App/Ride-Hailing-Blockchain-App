// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingDisputesDataStorage is DataStorageBaseContract {
    struct Dispute {
        address plaintiff;
        address defendant;
        string complaintDescription;
        string defenseDescription;
        bool resolved;
        uint256 plaintiffVotes;
        uint256 defendantVotes;
        address[] voterList; //only one person can vote once
        uint8[] voterChoice;
        address[] voteWinners;
    }
    Dispute[] private disputeData;

    function createDispute(
        address plaintiff,
        address defendant,
        string calldata complaintDescription
    ) external internalContractsOnly returns (uint256) {
        uint256 disputeId = disputeData.length;
        disputeData.push(
            Dispute(
                plaintiff,
                defendant,
                complaintDescription,
                "",
                false,
                0,
                0,
                new address[](0),
                new uint8[](0),
                new address[](0)
            )
        );
        return disputeId;
    }

    function getDispute(
        uint256 disputeId
    ) external view internalContractsOnly returns (Dispute memory) {
        return disputeData[disputeId];
    }

    function setDefenseDescription(
        uint256 disputeId,
        string calldata defenseDescription
    ) external internalContractsOnly {
        disputeData[disputeId].defenseDescription = defenseDescription;
    }

    function increasePlaintiffVotes(
        uint256 disputeId,
        address voter
    ) external internalContractsOnly {
        disputeData[disputeId].plaintiffVotes++;
        disputeData[disputeId].voterChoice.push(1); // 1 means vote for plaintiff
        disputeData[disputeId].voterList.push(voter);
    }

    function increaseDefendantVotes(
        uint256 disputeId,
        address voter
    ) external internalContractsOnly {
        disputeData[disputeId].defendantVotes++;
        disputeData[disputeId].voterChoice.push(2); // 2 means vote for defendant
        disputeData[disputeId].voterList.push(voter);
    }

    function getPlaintiffVotes(
        uint256 disputeId
    ) external view internalContractsOnly returns (uint256) {
        return disputeData[disputeId].plaintiffVotes;
    }

    function getDefendantVotes(
        uint256 disputeId
    ) external view internalContractsOnly returns (uint256) {
        return disputeData[disputeId].defendantVotes;
    }

    function getDefendant(uint256 disputeId) external view internalContractsOnly returns (address) {
        return disputeData[disputeId].defendant;
    }

    function getPlaintiff(uint256 disputeId) external view internalContractsOnly returns (address) {
        return disputeData[disputeId].plaintiff;
    }

    function checkDisputeExist(
        uint256 disputeId
    ) external view internalContractsOnly returns (bool) {
        if (disputeId > disputeData.length) {
            return false;
        } else {
            return true;
        }
    }

    function won(
        uint256 disputeId,
        uint256 winner
    ) external internalContractsOnly returns (address[] memory) {
        uint8[] memory voterChoiceFinal = disputeData[disputeId].voterChoice;
        for (uint256 i = 0; i <= voterChoiceFinal.length; i++) {
            if (voterChoiceFinal[i] == winner) {
                disputeData[disputeId].voteWinners.push(disputeData[disputeId].voterList[i]);
            }
        }
        return disputeData[disputeId].voteWinners;
    }

    function hasDispute(address user) external view internalContractsOnly returns (bool) {
        for (uint256 i = 0; i <= disputeData.length; i++) {
            if (disputeData[i].plaintiff == user || disputeData[i].defendant == user) {
                return true;
            }
        }
        return false;
    }
}
