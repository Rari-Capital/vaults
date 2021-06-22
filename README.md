# vaults

🧙‍♂️ Gas efficient yield aggregator to earn yield on any asset using Fuse 🧙‍♂️

## Table of contents

- [Installation](#installation)
  - [Nix](#first-install-nix)
  - [DappTools](#then-install-dapptools)
  - [Solc-Static](#finally-install-solc-static-076)
- [Developing](#developing)
  - [Compiling](#compiling)
  - [Testing](#testing)
  - [Debugging](#debugging)
- [Issues](https://github.com/rari-capital/vaults/projects/1)

## Installation

#### First, install Nix:

```sh
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

#### Then, install dapptools:

```sh
curl https://dapp.tools/install | sh
```

This configures the dapphub binary cache and installs the `dapp`, `solc`, `seth` and `hevm` executables.

#### Finally, install solc-static 0.7.6:

```sh
nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_0_7_6
```

This allows `dapp` to compile this project with the correct solc version.

## Developing

**Below is a brief summary of a few common commands you may need to contribute to this project.** If you are not already comfortable with the dapptools suite, [read the dapptools docs to learn more.](https://github.com/dapphub/dapptools/tree/master/src/dapp)

#### Compiling

```sh
dapp build
```

#### Testing

```sh
dapp test
```

#### Debugging

```sh
dapp debug
```
