//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../ERC20Mock.sol";
import {MockV3Aggregator} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract Handler is Test {
uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

   // HOw many times is mint call
   uint256 public numTimesMint;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;

    MockV3Aggregator public ethUsdPriceFeed;


    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        dsce = _engine;
        dsc = _dsc;
        // get tokens
        address[] memory tokenAddress = dsce.getCollaterTokens();
        weth = ERC20Mock(tokenAddress[0]);
        wbtc = ERC20Mock(tokenAddress[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));

    }
    // test that deposite is make before deposite collateral can be called

  function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

    // mint and approve!
    vm.startPrank(msg.sender);
    collateral.mint(msg.sender, amountCollateral);
    collateral.approve(address(dsce), amountCollateral);
    dsce.depositCollateral(address(collateral), amountCollateral);
    vm.stopPrank();
}

// redeem collateral test 
function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);
    amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
    if(amountCollateral == 0){
        return;
    }
    dsce.redeemCollateral(address(collateral), amountCollateral);
}

 // mint 
function mintDsc(uint256 amount) public {
    (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce._getAccountInformation(msg.sender);
    uint256 maxDscToMint = (collateralValueInUsd / 2) - totalDscMinted;
    if(maxDscToMint < 0){
        return;
    }
    amount = bound(amount, 0, maxDscToMint);
    if(amount < 0){
        return;
    }
    vm.startPrank(msg.sender);
    dsce.mintDSC(amount);
    vm.stopPrank();
    // increment
    numTimesMint ++;
}

    //----------- Helper Functions ------------------------------
function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock){
    if(collateralSeed % 2 == 0){
        return weth;
    }
    return wbtc;
}

function updateCollateralPrice(uint96 newPrice) public {
    int256 newPriceInt = int256(uint256(newPrice));
    ethUsdPriceFeed.updateAnswer(newPriceInt);
}
}
