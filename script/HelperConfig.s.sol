// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/ERC20Mock.sol";

pragma solidity ^0.8.20;

contract HelperConfig is Script {
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    //Network Config

    struct NetworkConfig {
        address wEthUSDPriceFeed;
        address wBTCUSDPriceFeed;
        address wEth;
        address wBTC;
        uint256 deployerKey;
    }

    // variables
    NetworkConfig public activeNetworkConfig;

    // constructor
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    // sepolia config
    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wEthUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBTCUSDPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wEth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return sepoliaNetworkConfig;
    }
    // anvil config

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        //CHECK IF WE ARE ON AVIL
        if (activeNetworkConfig.wEthUSDPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator wEthUSDPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        MockV3Aggregator wBTCUSDPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
        vm.stopBroadcast();

        NetworkConfig memory anvilNetworkConfig = NetworkConfig({
            wEthUSDPriceFeed: address(wEthUSDPriceFeed),
            wBTCUSDPriceFeed: address(wBTCUSDPriceFeed),
            wEth: address(wethMock),
            wBTC: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
        activeNetworkConfig = anvilNetworkConfig;
        return anvilNetworkConfig;
    }
}
