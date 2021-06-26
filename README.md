# vaults

🧙‍♂️ Gas efficient yield aggregator to earn yield on any asset using Fuse 🧙‍♂️

## Table of contents

- [Installation](#installation)
  - [Toolset](#toolset)
  - [Project Setup](#project-setup)
- [Developing](#developing)
  - [Compiling](#compiling)
  - [Testing](#testing)
  - [Debugging](#debugging)
- [Issues](https://github.com/rari-capital/vaults/projects/1)

## Installation

### Toolset

- First, install Nix:

```sh
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

- Then, install dapptools:

```sh
curl https://dapp.tools/install | sh
```

### Project Setup

- First, clone the repo locally:

```sh
git clone https://github.com/rari-capital/vaults
cd vaults
```

- Then setup the project:

```
make
```

## Developing

**Below is a brief summary of a few common commands you may need to contribute to this project.** If you are not already comfortable with the dapptools suite, [read the dapptools docs to learn more.](https://github.com/dapphub/dapptools/tree/master/src/dapp)

#### Compiling

```sh
make build # or 'dapp build'
```

Compiles the project.

#### Testing

```sh
make test # or 'dapp test --verbosity 1'
```

Test the project and only log verbose info for failed tests.

#### Verbose Testing

Test the project and log verbose info for everything.

```sh
make vtest # or 'dapp test --verbosity 3'
```

#### Debugging

```sh
mak debug # or 'dapp debug'
```

Run a test using the HEVM interactive debugger.
