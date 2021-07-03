# Install, update, build and test everything.
all: solc install update build test
# Install proper solc version.
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_0_8_6
# Install npm dependencies.
install:; npm install
# Install dapp dependencies.
update:; dapp update
# Compiles the project.
build:; dapp build
# Test the project.
test:; DAPP_SKIP_BUILD=1 dapp test