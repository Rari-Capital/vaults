let
  pkgs = import (builtins.fetchGit rec {
    name = "dapptools-${rev}";
    url = https://github.com/dapphub/dapptools;
    rev = "c20ca2d12b8df01a54665ce24a54957c5e94894c";
  }) {};

in
  pkgs.mkShell {
    src = null;
    name = "rari-capital-vaults";
    buildInputs = with pkgs; [
      pkgs.dapp
    ];
  }