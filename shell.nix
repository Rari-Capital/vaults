let
  pkgs = import (builtins.fetchGit rec {
    name = "dapptools-${rev}";
    url = https://github.com/dapphub/dapptools;
    rev = "e41b6cd9119bbd494aba1236838b859f2136696b";
  }) {};

in
  pkgs.mkShell {
    src = null;
    name = "rari-capital-vaults";
    buildInputs = with pkgs; [
      pkgs.dapp
    ];
  }