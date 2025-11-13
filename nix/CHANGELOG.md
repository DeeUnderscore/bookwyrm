# Bookwyrm Nix changelog
This covers changes to the Nix and NixOS packaging of Bookwyrm, not changes to Bookwyrm core itself.

## 0.8.1-nix1
* Updated to upstream tag 0.8.1. For 0.8.0 release notes, see <https://github.com/bookwyrm-social/bookwyrm/releases/tag/v0.8.0>. Note that upstream release notes recommend checking for and deleting any user exports that may have ended up publicly fetchable. This applies to deployments with tne Nix module provided. See the above link for details.
* Migrated from Poetry to uv, and from poetry2nix to uv2nix. poetry2nix is currently unmaintained, so uv and uv2nix are a better choice going forward.

## 0.7.5-nix2
* Update NixOS module for upstream NixOS module option name changes (namely `services.postgresql.port` → `services.postgresql.settings.port`)

## 0.7.5-nix1
* Updated to upstream version 0.7.5. See <https://github.com/bookwyrm-social/bookwyrm/releases/tag/v0.7.5>.

## 0.7.4-nix1
* Updated to upstream version 0.7.4. See <https://github.com/bookwyrm-social/bookwyrm/releases/tag/v0.7.4>.

## 0.7.3-nix1
* Updated to upstream version 0.7.3. See <https://github.com/bookwyrm-social/bookwyrm/releases/tag/v0.7.3>.

## 0.7.2-nix1
* Updated to upstream version 0.7.2. See <https://github.com/bookwyrm-social/bookwyrm/releases/tag/v0.7.2>. Note that upstream requires some Nginx configuration changes. Since the NixOS module here does not supply any Nginx configuration, these changes have to be applied by NixOS users of the module as well.

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
