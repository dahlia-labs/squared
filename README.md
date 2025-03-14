# 🌼 Dahlia, "numoen"

### Oracle-free lending markets

Smart contracts suite of Dahlia, a lending market for automated market maker shares to eliminate the oracle dependency of traditional lending markets. Thus, Dahlia enables lending and borrowing on any `ERC-20s` for leverage or yield.

## Installation


```bash
forge install dahlia-labs/dahlia
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
