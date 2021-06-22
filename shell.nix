let
  pkgs = import (builtins.fetchGit rec {
    name = "dapptools-${rev}";
    url = https://github.com/dapphub/dapptools;
    rev = "961dbcc6ec939103a1b78534d07672d7b4e642c1";
  }) {};

in
  pkgs.mkShell {
    src = null;
    name = "rari-capital-vaults";
    buildInputs = with pkgs; [
      pkgs.dapp
    ];
  }