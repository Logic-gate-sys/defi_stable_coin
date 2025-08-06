// SPDX-License-Identifier: MIT
// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin
// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions
// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/*
 * @title: DecentralizedStableCoin
 * @author: Daniel Kpatamia
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 * This is the contract meant to be governed by DSCEngine. 
 * This contract is just the ERC20 implementation of our stablecoin system.
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    //errors
    error DSC_AmountCannotBeZero();
    error DSC_NotEnoughFundToBurn();
    error DSC_CannotMintToAddressZero();
    error DSC_MintValueCannotBeLessThanOrEqualToZero();

    constructor(address initialOwner) ERC20("DecentralizedStableCoin", "DSC") Ownable(initialOwner) {}
    // function burn ; ONLY OWNER, AND NOT ZERO BURNT AND AMOUNT BURNT IS LESS OR EQUAL TO USER BALANCE

    function _burn(uint256 _amount) external onlyOwner returns (bool) {
        if (_amount <= 0) {
            revert DSC_AmountCannotBeZero();
        }
        if (_amount > balanceOf(msg.sender)) {
            revert DSC_NotEnoughFundToBurn();
        }
        super.burn(_amount);
        return true;
    }

    // minting
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DSC_CannotMintToAddressZero();
        }
        if (_amount <= 0) {
            revert DSC_MintValueCannotBeLessThanOrEqualToZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
