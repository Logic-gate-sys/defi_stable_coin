//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DeployDSCEngine} from "../script/DeployDSCEngine.s.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

contract DSCEngineTest is Test {
    //error
    error DSC_TokenAddressMustMatchPriceFeedAddress();

    HelperConfig config;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;

    // constants
    uint256 public constant INITIAL_BALANCE = 1000e8;
    address public USER = makeAddr("user");
    // state variables
    address wEthUSDAddress;
    address wEth;
    address wBTCUSDAddress;
    address wBTC;
    uint256 deployerKey;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function setUp() public {
        (dsc, dscEngine, config) = new DeployDSCEngine().run();
        (wEthUSDAddress, wBTCUSDAddress, wEth, wBTC, deployerKey) = config.activeNetworkConfig();
        //itialised wEth
        ERC20Mock mockToken = new ERC20Mock("WETH", "WETH", USER, INITIAL_BALANCE);

        tokenAddresses.push(wEth);
        priceFeedAddresses.push(wEthUSDAddress);
        priceFeedAddresses.push(wBTCUSDAddress);
    }

    // test DSCEngine constractor
    function testNewDSCEngineRevertIfArraysDonnotMatch() public {
        vm.expectRevert(DSCEngine.DSC_TokenAddressMustMatchPriceFeedAddress.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }
    // how much is 15 ether in used  from the getUSDValue function

    function testGetUSDValueOfEth() public {
        uint256 eth_amount = 15e18;
        uint256 expectedUSDValueOfwETH = 2000 * 15e18;
        uint256 valueReturned = dscEngine.getUSDValue(wEthUSDAddress, eth_amount);
        assertEq(expectedUSDValueOfwETH, valueReturned);
    }

    // test btc value in usd is correct
    function testBTCValueInUSDIsCorrect() public {
        uint256 btc_amount = 15e18;
        uint256 expectedUSDValueOfwBTC = 1000 * 15e18;
        uint256 valueReturned = dscEngine.getUSDValue(wBTCUSDAddress, btc_amount);
        assertEq(expectedUSDValueOfwBTC, valueReturned);
    }

    // test Mint sucessful
    function testUserIsAbleToDepositCollateralAndMintDSC() public {}

    //--------------------------- FUZZ TESTING ----------------------------------
}
