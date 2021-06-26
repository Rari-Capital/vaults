# Dapp Build Config.
export DAPP_BUILD_OPTIMIZE=1
export DAPP_BUILD_OPTIMIZE_RUNS=1000000000

# Install, update, build and test everything.
all: install update build test
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
# Debug the project.
debug:; dapp debug

