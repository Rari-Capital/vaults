export DAPP_BUILD_OPTIMIZE=1
export DAPP_BUILD_OPTIMIZE_RUNS=1000000000

all:; dapp build
test:; dapp test --verbosity 1
debug:; dapp debug