// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract DataStorageBaseContract {
    address private owner;
    address[] internalContracts;

    constructor(address ownerContract) {
        owner = ownerContract;
    }

    function setInternalContractAddresses(
        address[] calldata contractAddresses
    ) external ownerOnly {
        internalContracts = contractAddresses;
    }

    modifier internalContractsOnly() {
        bool addressMatched = false;
        for (uint i = 0; i < internalContracts.length; i++) {
            if (msg.sender == internalContracts[i]) {
                addressMatched = true;
                break;
            }
        }
        require(addressMatched, "Can only be called from internal contracts");
        _;
    }

    modifier ownerOnly() {
        require(msg.sender == owner, "Can only be called from owner contract");
        _;
    }
}
