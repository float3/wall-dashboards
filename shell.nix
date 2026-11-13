# A shell with the binary on PATH, by default with every panel:
#   nix-shell --arg panels '["air"]'
{
  pkgs ? import <nixpkgs> {},
  panels ? import ./panels.nix,
}:
pkgs.mkShell {
  packages = [(pkgs.callPackage ./package.nix {inherit panels;})];
}
