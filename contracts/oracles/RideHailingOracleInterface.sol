// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

abstract contract RideHailingOracleInterface {
    uint public constant AVG_FUEL_CONSUMPTION_PER_100_KM = 7;

    function petrolPricePerLitre() public view virtual returns (uint256);

    function prevailingWage() public view virtual returns (uint256);

    function estimateRideDuration(
        string memory start,
        string memory destination
    ) public virtual returns (uint256);

    function getTravelDistance(
        string memory start,
        string memory destination
    ) public virtual returns (uint256);

    function getSuggestedFare(
        string calldata start,
        string calldata destination
    ) external returns (uint256) {
        uint256 petrolCost = (getTravelDistance(start, destination) *
            AVG_FUEL_CONSUMPTION_PER_100_KM *
            petrolPricePerLitre()) / 100;
        uint256 driverWages = estimateRideDuration(start, destination) * prevailingWage();
        return driverWages + petrolCost;
    }

    function closestPointsToLocation(
        string[] calldata points,
        string calldata location,
        uint256 numPointsToReturn
    ) external virtual returns (string[] memory closestPoints);
}
