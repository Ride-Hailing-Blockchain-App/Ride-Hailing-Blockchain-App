// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./RideHailingOracleInterface.sol";

contract DummyOracle is RideHailingOracleInterface {
    uint256[10] randomTravelDistance = [9, 17, 6, 16, 20, 15, 2, 5, 10, 11];
    uint8 travelDistancePointer = 0;
    uint256 closestPointsPointer = 0;

    function petrolPricePerLitre() public pure override returns (uint256) {
        return 1600000000000000; // about 3 USD
    }

    function prevailingWage() public pure override returns (uint256) {
        return 4400000000000000; // about 8 USD
    }

    function estimateRideDuration(string memory, string memory) public pure override returns (uint256) {
        return 1;
    }

    function getTravelDistance(string memory, string memory) public override returns (uint256) {
        travelDistancePointer = (travelDistancePointer + 1) % 10;
        return randomTravelDistance[travelDistancePointer];
    }

    function closestPointsToLocation(
        string[] calldata points,
        string calldata, //location
        uint256 numPointsToReturn
    ) external override returns (string[] memory) {
        require(numPointsToReturn <= points.length, "numPointsToReturn should be less than size of points");
        string[] memory closestPoints = new string[](numPointsToReturn);
        for (uint8 i = 0; i < numPointsToReturn; i++) {
            closestPoints[i] = points[closestPointsPointer % points.length];
            closestPointsPointer++;
        }
        return closestPoints;
    }
}
