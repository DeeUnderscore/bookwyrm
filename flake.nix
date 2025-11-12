{
  description = "NixOS module and package for the Bookwyrm decentralized reading and reviewing server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
      ...
    }@inputs:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        workspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = ./.;
        };

        pythonOverlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        pythons =
          let
            origPython = pkgs.python3;
            pythonBase = pkgs.callPackage pyproject-nix.build.packages {
              python = origPython;
            };
          in
          pythonBase.overrideScope (
            nixpkgs.lib.composeManyExtensions [
              pyproject-build-systems.overlays.wheel
              pythonOverlay
              (import ./nix/pyproject-overrides.nix { inherit pkgs; })
            ]
          );
      in
      {
        packages.bookwyrm = pythons.mkVirtualEnv "bookwyrm" workspace.deps.default;

        defaultPackage = self.packages.${system}.bookwyrm;
      }
    )
    // {
      nixosModule =
        { config, pkgs, ... }:
        {
          imports = [
            ./nix/module.nix
          ];

          services.bookwyrm.package = self.packages.${pkgs.system}.bookwyrm;
        };
      overlay = (
        final: prev: {
          bookwyrm = self.packages.${final.system}.bookwyrm;
        }
      );
    };
}
