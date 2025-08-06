# Our stablecoin is going to be:

- Relative Stability: Anchored or Pegged to the US Dollar

   - Chainlink Pricefeed

   - Function to convert ETH & BTC to USD

- Stability Mechanism (Minting/Burning): Algorithmicly Decentralized

    - Users may only mint the stablecoin with enough collateral

- Collateral: Exogenous (Crypto)

wETH

wBTC

## To add some context to the above, we hope to create our stablecoin in such a way that it is pegged to the US Dollar. We'll achieve this by leveraging chainlink pricefeeds to determine the USD value of deposited collateral when calculating the value of collateral underlying minted tokens.

The token should be kept stable through this collateralization stability mechanism.

For collateral, the protocol will accept wrapped Bitcoin and wrapped Ether, the ERC20 equivalents of these tokens.