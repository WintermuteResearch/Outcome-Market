# Specialized OutcomeMarket

This set of contracts could be used for the 2024 US elections outcome market. The main idea is to provide the tooling for minting tokens with USDC to get preferred exposure on various trading venues. At the settlement time, a token related to the winning outcome could be redeemed 1:1. In the case when neither Trump nor Harris wins this election, the settlement is 0.5 USDC per 1 unit of any outcome token.

`OutcomeMarket` and `OutcomeERC20` are provided by Wintermute Research, and `ElectionOracle` is by Chaos Labs. The oracle provider will deliver the right result to the relevant Edge Proof oracle contract (`0x7fa7d43Cf434A5E22a8841Fd4933fE135AF6B2cF`) according to [the methodology](https://github.com/ChaosLabsInc/election-oracle/blob/main/docs/Edge%20Proof%20Oracle%20for%20Determining%20the%202024%20U%20S%20Ele%2010b57ab37ebf8023b010e4368e55b633.md).

These contracts could be deployed on Ethereum, Base and Arbitrum for the usage with native USDC as collateral.