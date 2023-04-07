// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./DataStorageBaseContract.sol";

contract RideHailingDisputesDataStorage is DataStorageBaseContract {
    struct Dispute {
        address plaintiff;
        address defendant;
        string complaintDescription;
        string defenseDescription;
        bool responded;
        bool carFeeDispute;
        bool compensationDispute;
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
                carFeeDispute,
                compensationDispute,
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

    function getRideId(
        uint256 disputeId
    ) external view internalContractsOnly returns (uint) {
        return disputeData[disputeId].rideId;
    }

    function setDisputeResponse (
        uint256 disputeId
    ) external internalContractsOnly {
        disputeData[disputeId].responded = true;
    }

    function getNumOfDefedantUnresponded( //check if have respond to disputes
        address defendant
    ) external view internalContractsOnly returns (uint256) {
        uint unrespondCounter = 0;
        for(uint i = 0; i < disputeData.length; i++) {
            if(disputeData[i].defendant == defendant && disputeData[i].responded == false)
            unrespondCounter ++;
        }
        return unrespondCounter;
    }

    function getTimeRemaining(uint256 disputeId) external view internalContractsOnly returns (uint256) {
        uint256 timePassed = block.timestamp - disputeData[disputeId].startTime;
        if(timePassed >= 1 days) {
            return 0;
        } else {
            return 1 days - timePassed;
        }
    }


    function generateDisputeForVoting() external view returns (uint256) {
        // dummy oracle : get unresolved dispute by rng
        for (uint256 i = 0; i < disputeData.length; i++) {
            if (disputeData[i].resolved != true) {
                return i; // i is the disputeId
            }
        }
        // returns max uint256 value if no unresolved dispute found
        return (2 ^ (256 - 1));
    }

    function checkDisputeStatus(
        uint256 disputeId
    ) external view returns (bool) {
        return disputeData[disputeId].resolved;
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
