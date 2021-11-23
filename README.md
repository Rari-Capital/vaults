# Vaults • [![Tests](https://github.com/Rari-Capital/vaults/actions/workflows/tests.yml/badge.svg)](https://github.com/Rari-Capital/vaults/actions/workflows/tests.yml) [![License](https://img.shields.io/badge/License-AGPL--3.0-blue)](LICENSE.md)

Flexible, minimalist, and **gas-optimized yield aggregator protocol** for earning interest on any ERC20 token.

- [Documentation](https://docs.rari.capital/yag/)
- [Deployments](https://github.com/Rari-Capital/vaults/releases)
- [Whitepaper](whitepaper/Whitepaper.pdf)
- [Audits](audits)

## Architecture

- [`Vault.sol`](src/Vault.sol): Flexible, minimalist, and gas-optimized yield aggregator for earning interest on any ERC20 token.
- [`VaultFactory.sol`](src/VaultFactory.sol): Factory which enables deploying a Vault contract for any ERC20 token.
- [`modules/`](src/modules): Contracts used for managing and/or simplifying interaction with Vaults and the Vault Factory.
  - [`VaultRouterModule.sol`](src/modules/VaultRouterModule.sol): Module that enables depositing ETH and approval-free deposits via permit.
  - [`VaultAuthorityModule.sol`](src/modules/VaultAuthorityModule.sol): Module for managing access to secured Vault operations.
  - [`VaultConfigurationModule.sol`](src/modules/VaultConfigurationModule.sol): Module for configuring Vault parameters.
  - [`VaultInitializationModule.sol`](src/modules/VaultInitializationModule.sol): Module for initializing newly created Vaults.
- [`interfaces/`](src/interfaces): Interfaces of external contracts Vaults and modules interact with.
  - [`Strategy.sol`](src/interfaces/Strategy.sol): Minimal interfaces for ERC20 and ETH compatible strategies.

![Diagram](https://lucid.app/publicSegments/view/bb0628f9-8cfe-4979-9fc1-7ba6e51f7afc/image.png)

## Contributing

You will need a copy of [DappTools](https://dapp.tools) installed before proceeding. See the [installation guide](https://github.com/dapphub/dapptools#installation) for details.

### Setup

```sh
git clone https://github.com/Rari-Capital/vaults.git
cd vaults
make
```

### Run Tests

```sh
dapp test
```

### Measure Coverage

```sh
dapp test --coverage
```

### Update Gas Snapshots

```sh
dapp snapshot
```
