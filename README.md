# Specialized Outcome Market

This set of contracts is the market for the 2024 US elections outcome. The main idea is to provide the tooling for minting conditional tokens with USDC to get preferred exposure using various RFQ/CLOB exchanges. At the settlement time, a token related to the winning outcome could be redeemed 1:1. In the case when nor Trump nor Harris would win this election, the settlement is 0.5 USDC per 1 unit for any of outcome tokens. 

`OutcomeMarket` and `OutcomeERC20` are provided by Wintermute Research, and `ElectionOracle` is by Chaos Labs. The oracle provider will do all necessary work to ensure that the right result will be provided to their contract according to the methodology.

### Assumptions:
- all contracts except the oracle one should be totally permissionless
- this set of contracts will be deployed on Ethereum, Base and Arbitrum
- the collateral on all chains will be the native USDC (6 decimals)
- the oracle provider will try to deliver the right result using its current contract, so assuming no rug risk from the oracle
- we're aware about the MEV opportunity (`mint()`, `resolve()`, sell all loser tokens for winner ones, `redeem()`) atomically or using tx bundles. We can't see this as in issue in the current form because the oracle result will be delivered with a delay, so this type of arbitrage could be performed much earlier