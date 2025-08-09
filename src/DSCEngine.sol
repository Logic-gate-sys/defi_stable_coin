/*
------- DSCEngine will be the heart of the protocol which manages all aspects of : 
             -minting, 
             -burning, 
             -collateralizing
             -liquidating 
             within our protocol.
*/

//SPDX-License-Identifier: MIT
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

pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from './libraries/OracleLib.sol';
/*
 * @title DSCEngine
 * @author Daniel Kpatamia
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DSCEngine is ReentrancyGuard {
    //custom errors :
    error DSCEngine__NeedsMoreThanZero();
    error DSC_OnlyAllowedTokenAddress();
    error DSC_TokenAddressMustMatchPriceFeedAddress();
    error DSC_TransferFromFailed();
    error DSC_UserHealthFactorBroken(uint256);
    error DSC_MintFailed();
    error DSC_HealthFactorOk();
    error DSC_HealthFactorNotImproved();

    //state variables
    mapping(address tokenAddress => address priceFeedAddress) private s_tokenAddressToPriceFeedAddress;
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address user => mapping(address tokenAddress => uint256 _amount)) private s_collateralDepositedByUser;
    mapping(address user => uint256 amountOfDSCMinted) private s_userToDSCMinted;
    address[] private s_collateralTokens;

    //constants
    uint256 private constant ADDITIONAL_FEED_PRICISION = 1e10;
    uint256 private constant LIQUIDATTION_BONUS = 10; // 10%
    uint256 private constant PRECISSION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 50%
    uint256 private constant LIQUIDATION_PRECISION = 100; // can devited by 100%
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // to represent 1 ;
    //----------- Types -------------------- 
    using OracleLib for AggregatorV3Interface;

    //events
    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    //modifiers
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier onlyAllowedTokenAddress(address tokenAddress) {
        if (s_tokenAddressToPriceFeedAddress[tokenAddress] == address(0)) {
            // zero is default for none the mapping
            revert DSC_OnlyAllowedTokenAddress();
        }
        _;
    }
    ///////////////////
    //   Functions   //
    ///////////////////

    constructor(address[] memory _tokenAddress, address[] memory _priceFeedAddress, address _dscAddress) {
        if (_tokenAddress.length != _priceFeedAddress.length) {
            revert DSC_TokenAddressMustMatchPriceFeedAddress();
        }
        for (uint256 i = 0; i < _tokenAddress.length; i++) {
            s_tokenAddressToPriceFeedAddress[_tokenAddress[i]] = _priceFeedAddress[i];
            //add allowed token address to the collateral tokens array
            s_collateralTokens.push(_tokenAddress[i]);
        }
        // initialise DSC
        i_dsc = DecentralizedStableCoin(_dscAddress); // casting to contract
    }

    ///////////////////////////
    //   External Functions  //
    ///////////////////////////
    /*
    * @param tokenCollateralAddress: the address of the token to deposit as collateral
    * @param amountCollateral: The amount of collateral to deposit
    * @param amountDscToMint: The amount of DecentralizedStableCoin to mint
    * @notice: This function will deposit your collateral and mint DSC in one transaction
    */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) public {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }

    /*
    * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
    * @param amountCollateral: The amount of collateral you're depositing
    */
    function depositCollateral(address _tokenCollateralAddress, uint256 _amount)
        public
        moreThanZero(_amount)
        onlyAllowedTokenAddress(_tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDepositedByUser[msg.sender][_tokenCollateralAddress] += _amount;
        // state change occur because we modified user deposite; so we have to emit
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amount);
        // let transfer the collateral from the user
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert DSC_TransferFromFailed();
        }
    }
    ////////////////////////////////////////////////
    // Private and Internal View Functions                    ///
    ////////////////////////////////////////////////

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        // let's go
        s_collateralDepositedByUser[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSC_TransferFromFailed();
        }
    }

    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSC_UserHealthFactorBroken(userHealthFactor);
        }
    }

    //check accounts healthfactor
    /*
    * Returns how close to liquidation a user is
    * If a user goes below 1, then they can be liquidated.
    */
    function _healthFactor(address _user) internal view returns (uint256) {
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(_user);
        uint256 collateralAdjustedForLiquidation =
            (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForLiquidation * PRECISSION) / totalDSCMinted;
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISSION) / totalDscMinted;
    }
    // get account informations of a user

    function _getAccountInformation(address _user) public view returns (uint256, uint256) {
        //total dsc minted
        uint256 totalDSCMinted = s_userToDSCMinted[_user];
        //total collateral in USD
        uint256 totalCollaterValue = getAccountCollaralValue(_user);
        return (totalDSCMinted, totalCollaterValue);
    }

    // get accoutn collateral value
    function getAccountCollaralValue(address _user) public view returns (uint256) {
        uint256 totalCollateralValueInUSD;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address tokenAddr = s_collateralTokens[i];
            uint256 collateralByUser = s_collateralDepositedByUser[_user][tokenAddr];
            totalCollateralValueInUSD += getUSDValue(tokenAddr, collateralByUser);
        }
        return totalCollateralValueInUSD;
    }
    // convert amount collateral to usd

    function getUSDValue(address _token, uint256 _amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_token);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (((_amount * (uint256(price) * ADDITIONAL_FEED_PRICISION)) / PRECISSION));
    }
    // minting

    function mintDSC(uint256 _amountOfDSCToMint) public moreThanZero(_amountOfDSCToMint) nonReentrant {
        s_userToDSCMinted[msg.sender] += _amountOfDSCToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_dsc.mint(msg.sender, _amountOfDSCToMint);
        if (!success) {
            revert DSC_MintFailed();
        }
    }

    // ---------------------- REDEEEM COLLATERAL ----------------------
    /*
    * @param tokenCollateralAddress: the collateral address to redeem
    * @param amountCollateral: amount of collateral to redeem
    * @param amountDscToBurn: amount of DSC to burn
    * This function burns DSC and redeems underlying collateral in one transaction
    */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    // user can get token
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        emit CollateralRedeemed(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        // now lets send DSC to user
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSC_TransferFromFailed();
        }
        // check health factor : this is for effieciency rather than saving gas
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // --------------- what if a user want's to exit the protocol -------------------------------------
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_userToDSCMinted[onBehalfOf] -= amountDscToBurn;

        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        // This conditional is hypothetically unreachable
        if (!success) {
            revert DSC_TransferFromFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    /*
    * @param amountDscToMint: The amount of DSC you want to mint
    * You can only mint DSC if you have  enough collateral
    */

    // ----------------------- Liquidations ---------------------------
    /*
    * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
    * This is collateral that you're going to take from the user who is insolvent.
    * In return, you have to burn your DSC to pay off their debt, but you don't pay off your own.
    * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
    * @param debtToCover: The amount of DSC you want to burn to cover the user's debt.
    *
    * @notice: You can partially liquidate a user.
    * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
    * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this
    to work.
    * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate
    anyone.
    * For example, if the price of the collateral plummeted before anyone could be liquidated.
    */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor > MIN_HEALTH_FACTOR) {
            revert DSC_HealthFactorOk();
        }
        // how much in USD of the depth is the new user covering
        uint256 tokenAmountFromDeptCovered = getTokenAmountInUSD(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDeptCovered * LIQUIDATTION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralRedeemed = tokenAmountFromDeptCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralRedeemed, user, msg.sender);
        // burn on behalf or user ;
        _burnDsc(debtToCover, user, msg.sender);

        // if liquidation does solve users health factor then it 's best we revert
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSC_HealthFactorNotImproved();
        }
        // check that the liquidator's health factor is also not broken
        _healthFactor(msg.sender);
    }

    function getTokenAmountInUSD(address collateral, uint256 debtToCover) public returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(collateral); // token_collateral address
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint256 USDValue = (debtToCover * (uint256(price) * ADDITIONAL_FEED_PRICISION)) / PRECISSION;
        return USDValue;
    }

    // ------------------------ Getters and Setters --------------------------
    function getMintedTokens(address user) public returns (uint256) {
        return s_userToDSCMinted[user];
    }

    function getHealthFactor() external view {}

    //- ---------------- views ---------------------------------
    function getCollaterTokens() public view returns (address[] memory) {
        return s_collateralTokens;
    }

 function getCollateralTokenPriceFeed(address weth) public view  returns(address) {
        return s_tokenAddressToPriceFeedAddress[weth];
 }
    function getCollateralBalanceOfUser(address col_token_addres, address user) public view returns(uint256) {
        return s_collateralDepositedByUser[user][col_token_addres];

    }

    /*
    * Returns how close to liquidation a user is
    * If a user goes below 1, then they can be liquidated.
    Example: 
    Say a user deposits $150 worth of ETH and goes to mint $100 worth of DSC.
    Then
    (150 * 50) / 100 = 75
    return (75 * 1e18) / 100e18
    return (0.75)
    */
}
// user's information

/*
We will need:

# Deposit collateral and mint the DSC token

This is how users acquire the stablecoin, they deposit collateral greater than the value of the DSC minted

Redeem their collateral for DSC

Users will need to be able to return DSC to the protocol in exchange for their underlying collateral

# Burn DSC

If the value of a user's collateral quickly falls, users will need a way to quickly rectify the collateralization of their DSC.

# The ability to liquidate an account

Because our protocol must always be over-collateralized (more collateral must be deposited then DSC is minted), if a user's
 collateral value falls below what's required to support their minted DSC, they can be liquidated. Liquidation allows other
  users to close an under-collateralized position

# View an account's healthFactor

healthFactor will be defined as a certain ratio of collateralization a user has for the DSC they've minted.
 As the value of a user's collateral falls, as will their healthFactor, if no changes to DSC held are made. 
 If a user's healthFactor falls below a defined threshold, the user will be at risk of liquidation.

eg. If the threshold to liquidate is 150% collateralization, an account with $75 in ETH can support $50 in DSC.
 If the value of ETH falls to $74, the healthFactor is broken and the account can be liquidated
*/
