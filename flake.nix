{
  description = "A Nix Flake Based Odin Development Environment & Package for nixfetch";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # defines system that this flake supports
    systems.url = "github:nix-systems/default-linux";
    # powered by
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    # rust overlay package
    odin-overlay = {
      url = "github:ArMonarch/odin-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {flake-parts, ...} @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import inputs.systems;

      perSystem = {
        pkgs,
        system,
        ...
      }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.odin-overlay.overlays.odin-overlay
            inputs.odin-overlay.overlays.ols-overlay
          ];
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            odin-bin."dev-2026-03".latest
            ols-bin."dev-2026-02".latest
            llvmPackages.bintools-unwrapped
            valgrind
            just
            perf
          ];
          shellHook = ''
            echo "Initialized Odin Development Environment"
            echo "  ├── $(odin version)"
            echo "  ├── $(ols version)"
            echo "  ├── $(just --version)"
            echo "  ├── $(perf version)"
            echo "  └── $(valgrind --version)"
          '';
        };

        packages.default = pkgs.callPackage ./nix/package.nix {};
      };
    };
}
