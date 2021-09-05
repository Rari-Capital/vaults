# vaults

Gas efficient yield aggregator to earn interest on any asset using Fuse.

## Installation

### Toolset

- First, install Nix:

```sh
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

- Then, install DappTools:

```sh
curl https://dapp.tools/install | sh
```

### Project Setup

- First, clone the repo locally:

```sh
git clone https://github.com/rari-capital/vaults
cd vaults
```

- Then, install the project's dependencies:

```sh
make
```

## Developing

Read the [DappTools documentation](https://github.com/dapphub/dapptools/tree/master/src/dapp) to learn more.

### Compiling

```sh
dapp build
```

Compiles the project.

### Testing

```sh
dapp test
```

Test the project and only log verbose info for failed tests.

### Verbose Testing

```sh
dapp test --verbosity 2
```

Test the project and show ds-test logs for everything.

### Very Verbose Testing

```sh
dapp test --verbosity 3
```

Test the project and log full verbose info for everything.

### Debugging

```sh
dapp debug
```

Run a test using the interactive debugger.

### Replaying

```sh
dapp debug --replay '("test_exchange_rate_increases(uint256)","0x0000000000000000000000000000000000000000000000000000000000000001")'
```

Replay a specific testcase in the debugger.
