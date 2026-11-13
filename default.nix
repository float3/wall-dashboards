# Builds without flakes. `wall-dashboards` has every panel; `air`, `weather`
# and `transit` have one each. Other sets come from `.override`:
#   (import ./. {}).wall-dashboards.override {panels = ["air" "weather"];}
{pkgs ? import <nixpkgs> {}}: let
  build = panels: pkgs.callPackage ./package.nix {inherit panels;};
in
  {wall-dashboards = pkgs.callPackage ./package.nix {};}
  // pkgs.lib.genAttrs (import ./panels.nix) (panel: build [panel])
