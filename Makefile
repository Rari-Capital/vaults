# Dapp Build Config.
export DAPP_BUILD_OPTIMIZE=1
export DAPP_BUILD_OPTIMIZE_RUNS=1000000000
export DAPP_TEST_FUZZ_RUNS=5000

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
# Test the project and only log verbose info for failed tests.
test:; dapp test --verbosity 1
# Test the project and log verbose info for everything.
vtest:; dapp test --verbosity 3
# Run a test using the HEVM interactive debugger.
debug:; dapp debug

