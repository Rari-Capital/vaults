# vaults

🧙‍♂️ Gas efficient yield aggregator to earn yield on any asset using Fuse 🧙‍♂️

## Installation

### First, install Nix:

```sh
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

### Then, install dapptools:

```sh
curl https://dapp.tools/install | sh
```

This configures the dapphub binary cache and installs the `dapp`, `solc`, `seth` and `hevm` executables.

### Finally, install solc-static 0.7.6:

```sh
nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_0_7_6
```

This allows `dapp` to compile this project with the correct solc version.

## Developing

Below is a brief summary of common commands you may wish to use while developing for this project. [Read the dapptools docs to learn more about `dapp`'s capabilities!](https://github.com/dapphub/dapptools/tree/master/src/dapp)

```sh
dapp build
```

Compiles the project.

```sh
dapp test
```

Runs the project's tests.

```sh
dapp debug
```

Debug a specific test.
