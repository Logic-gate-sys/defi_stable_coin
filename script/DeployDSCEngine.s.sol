// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDSCEngine is Script {
    address[] tokenAddress;
    address[] priceFeedAddreses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address wEthUSDPriceFeed, address wBTCUSDPriceFeed, address wEth, address wBTC, uint256 deployerKey) =
            config.activeNetworkConfig();
        // arrays
        tokenAddress = [wEth, wBTC];
        priceFeedAddreses = [wEthUSDPriceFeed, wBTCUSDPriceFeed];

        // deploy
        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin(address(this));
        DSCEngine dscEngine = new DSCEngine(tokenAddress, priceFeedAddreses, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.startBroadcast();
        return (dsc, dscEngine, config);
    }
}
