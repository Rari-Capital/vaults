let
  pkgs = import (builtins.fetchGit rec {
    name = "dapptools-${rev}";
    url = https://github.com/dapphub/dapptools;
    rev = "a15951d25913002a4fe2e61d14941f45c375560d";
  }) {};

in
  pkgs.mkShell {
    src = null;
    name = "rari-capital-vaults";
    buildInputs = with pkgs; [
      pkgs.dapp
    ];
  }