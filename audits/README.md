# Smart Contract Audits

Welcome to the audit/ folder. Here you'll find more information regarding the vulnerability and shortcomings of the smart contract.

## About the MetaZero Staking Contract

I initially wrote the staking contract as a simple staking pool. However as requirements were added during build time, the complexity increased. Thanks to a few auditors we've managed to secure the contract and avoid having left over funds in the address in case the math is incorrect. There is a loss of about 1 wei per staker that will stay in the contract.
Would need more time to completely remove that precision loss, and it was marked as acceptable.
Check out the ThreeSigma audit for more information.

## Audit Reports

Detailed audit reports by Assure DeFi and ThreeSigma are available in this repository. I've also included the link to their repo and website.


### Assure DeFi Audit

The audit conducted by [Assure DeFi](https://github.com/Assure-DeFi) provides an analysis of the smart contract. The full report is accessible below:

- [Assure DeFi Audit Report](https://github.com/Assure-DeFi/Audits/blob/main/METAZERO_ADVANCED_04_11_24.pdf)

### ThreeSigma Audit

ThreeSigma, known for their rigorous audit processes, have also reviewed our staking contract. Details of their audit findings can be found in the following document:

- [ThreeSigma Audit Report](https://github.com/threesigmaxyz/publications/blob/main/audits/metazero-2/MetazeroStakingAudit.pdf)
- And here is their annoucement tweet: [Twitter feed](https://twitter.com/threesigmaxyz/status/1778325493047242840).

