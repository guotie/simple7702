// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error LengthMismatch();
error NotOwner(address caller);
error OwnerIsZeroAddress();

contract Simple7702PolicyRegistry {
    address public owner;
    bool public enableSponsorWhitelist;
    bool public enableTargetWhitelist;

    mapping(address => bool) public sponsorWhitelist;
    mapping(address => bool) public targetWhitelist;

    event OwnerTransferred(address indexed previousOwner, address indexed newOwner);
    event SponsorWhitelistUpdated(address indexed sponsor, bool allowed);
    event TargetWhitelistUpdated(address indexed target, bool allowed);
    event WhitelistFlagsUpdated(bool enableSponsorWhitelist, bool enableTargetWhitelist);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnerIsZeroAddress();
        owner = initialOwner;
        emit OwnerTransferred(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OwnerIsZeroAddress();

        address previousOwner = owner;
        owner = newOwner;
        emit OwnerTransferred(previousOwner, newOwner);
    }

    function setWhitelistFlags(bool sponsorEnabled, bool targetEnabled) external onlyOwner {
        enableSponsorWhitelist = sponsorEnabled;
        enableTargetWhitelist = targetEnabled;
        emit WhitelistFlagsUpdated(sponsorEnabled, targetEnabled);
    }

    function setSponsorWhitelist(address sponsor, bool allowed) external onlyOwner {
        sponsorWhitelist[sponsor] = allowed;
        emit SponsorWhitelistUpdated(sponsor, allowed);
    }

    function setTargetWhitelist(address target, bool allowed) external onlyOwner {
        targetWhitelist[target] = allowed;
        emit TargetWhitelistUpdated(target, allowed);
    }

    function setSponsorWhitelistBatch(address[] calldata sponsors, bool[] calldata allowed) external onlyOwner {
        uint256 length = sponsors.length;
        if (length != allowed.length) revert LengthMismatch();

        for (uint256 i = 0; i < length; ++i) {
            sponsorWhitelist[sponsors[i]] = allowed[i];
            emit SponsorWhitelistUpdated(sponsors[i], allowed[i]);
        }
    }

    function setTargetWhitelistBatch(address[] calldata targets, bool[] calldata allowed) external onlyOwner {
        uint256 length = targets.length;
        if (length != allowed.length) revert LengthMismatch();

        for (uint256 i = 0; i < length; ++i) {
            targetWhitelist[targets[i]] = allowed[i];
            emit TargetWhitelistUpdated(targets[i], allowed[i]);
        }
    }
}
