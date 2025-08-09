// //SPDX-License-Identifier:MIT
// pragma solidity 0.8.20;

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract InvariantsTest is StdInvariant, Test {
//     HelperConfig config;
//     DeployDSCEngine deployer;
//     DSCEngine dscEngine;
//     DecentralizedStableCoin dsc;
//     address wbtc;
//     address weth;

//     function setUp() public {
//         deployer = new DeployDSCEngine();
//         (dsc, dscEngine, config) = deployer.run();
//         //get tokens
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         targetContract(address(dscEngine));
//     }

//     //test protocol always has more collateral value than total token supply
//     function invariant_DSCAlwaysHasMoreCollateralThanTokenSupply() public view {
//         // supply
//         uint256 total_supply = dsc.totalSupply();
//         uint256 total_wEthDeposited = IERC20(weth).balanceOf(address(dscEngine));
//         uint256 total_wbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
//         //usd values
//         uint256 wethValue = dscEngine.getUSDValue(weth, total_wEthDeposited);
//         uint256 wbtcValue = dscEngine.getUSDValue(wbtc, total_wbtcDeposited);
//         assert(wethValue + wbtcValue >= total_supply);
//     }
// }
