{
  description = "NixOS module and package for the Bookwyrm decentralized reading and reviewing server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      ...
    }@inputs:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ inputs.poetry2nix.overlays.default ];
        };
      in
      {
        packages.bookwyrm = pkgs.callPackage ./nix/default.nix { };

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
          bookwyrm = prev.callPackage ./nix/default.nix { };
        }
      );
    };
}
