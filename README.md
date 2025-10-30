# Squared

The repository contains the smart contracts suite of Squared, an automated market maker that interacts with external lending markets to boostrap [variance swaps](https://en.wikipedia.org/wiki/Variance_swap) on any ERC-20 token. The mechanism is competely onchain and works in the absence of an existing market and traditional market makers. Thereby enabling traders to hedge cryptocurrency volatilty and [gamma risk associated with Uniswap liquidity provisioning](https://arxiv.org/abs/2111.09192). Beyond hedging, Squared acts as an oracle for realized volatility on any ERC-20 token. 

The codebase is an implementation of the [capped quadratic market maker](https://arxiv.org/abs/2111.13740) that mimics a variance swap exposure. We were luckily enough to recieve a small [grant](https://mirror.xyz/0x5419AEF6D232A2168bEa5d9418C86493990c81e1/42TJikHaCauYAmanTiXJRT1sp8N21U6hIegWCOurhDA) from the Uniswap Foundation in 2022 to build Squared. 
## Installation


```bash
forge install dahlia-labs/squared
```

## Local development

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.

### Dependencies

```bash
forge install

@openzeppelin/contracts-upgrade
@transmissions11/solmate
```

#### CREATE2

The `factory.sol` deploys `squared.sol` to a predetermined address using `.create2deploy()`

### Compilation

```bash
forge build
```

### Test

```bash
forge test
```

### Local setup

In order to test third party integrations such as interfaces, it is possible to set up a forked mainnet with several positions open

```bash
sh anvil.sh
```

then, in a separate terminal,

```bash
sh setup.sh
```
