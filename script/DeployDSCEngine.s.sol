// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDSCEngine is Script {
    address[] tokenAddress;
    address[] priceFeedAddreses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address wEthUSDPriceFeed, address wBTCUSDPriceFeed, address wEth, address wBTC,) = config.activeNetworkConfig();
        // arrays
        tokenAddress = [wEth, wBTC];
        priceFeedAddreses = [wEthUSDPriceFeed, wBTCUSDPriceFeed];

        // deploy
        vm.startBroadcast();
        //  DecentralizedStableCoin dsc = new DecentralizedStableCoin(msg.sender)
        DecentralizedStableCoin dsc = new DecentralizedStableCoin(tx.origin); // INITIAL OWNER <===== DeployDSCEngine
        DSCEngine dscEngine = new DSCEngine(tokenAddress, priceFeedAddreses, address(dsc));
        // dsc.transferOwnership(address(dscEngine)); // transfer ownership to dscEngine
        vm.stopBroadcast();
        return (dsc, dscEngine, config);
    }
}
