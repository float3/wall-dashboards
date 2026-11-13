{
  lib,
  rustPlatform,
  # Panels to compile in. Leaving out weather and transit also leaves out the
  # TLS stack.
  panels ? import ./panels.nix,
}:
rustPlatform.buildRustPackage {
  pname = "wall-dashboards";
  version = "0.2.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
      # The pages are baked into the binary with include_str!.
      ./pages
    ];
  };

  # The lock file is the source of truth, so there is no cargoHash to keep in
  # step with it.
  cargoLock.lockFile = ./Cargo.lock;

  # Checked here so a typo fails evaluation rather than deep inside cargo.
  buildNoDefaultFeatures = true;
  buildFeatures =
    lib.throwIf (panels == []) "wall-dashboards: pick at least one panel"
    (lib.throwIfNot (lib.all (p: lib.elem p (import ./panels.nix)) panels)
      "wall-dashboards: unknown panel in ${toString panels}"
      panels);

  meta = {
    description = "Air quality, weather and departure panels for a wall display";
    homepage = "https://github.com/float3/wall-dashboards";
    license = lib.licenses.mit;
    mainProgram = "wall-dashboards";
    platforms = lib.platforms.linux;
  };
}
