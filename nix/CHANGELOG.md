# Bookwyrm Nix changelog
This covers changes to the Nix and NixOS packaging of Bookwyrm, not changes to Bookwyrm core itself.

## 0.7.1-nix1
* Updated to upstream vesion 0.7.1. See <https://github.com/bookwyrm-social/bookwyrm/releases/tag/v0.7.1>
* Tweaked local poetry2nix overrides. If this causes problems, ensure Bookwyrm is being built against recent poetry2nix (the flake locked version works).

## 0.7.0-nix3
* Updated flake lock, including poetry2nix, to resolve problem with failing builds using locked poetry2nix combined with newer Nixpkgs revisions. 

## 0.7.0-nix2
* Switched to separate flake input for poetry2nix, as poetry2nix is being dropped from Nixpkgs proper (see <https://github.com/NixOS/nixpkgs/pull/263308>). The overlay output of this flake remains unchanged, which means it will break on newer Nixpkgs master, unless the Nixpkgs it is used on is also overlaid with the poetry2nix overlay. The module output of this flake no longer overlays anything over the system Nixpkgs.

## 0.7.0-nix1
* Updated to upstream version 0.7.0. See <https://github.com/bookwyrm-social/bookwyrm/releases/tag/v0.7.0>

## 0.6.6-nix1
* Updated to upstream version 0.6.6. See <https://github.com/bookwyrm-social/bookwyrm/releases/tag/v0.6.6>

## 0.6.5-nix3
* The flake now outputs an overlay with `pkgs.bookwyrm`.
* The NixOS module now adds an overlay, and builds Bookwyrm through overlay. `services.bookwyrm.package` is now exposed to allow changing the Bookwyrm package used, so it is possible to pass the flake's `defaultPackage` down to it if so desired. 
