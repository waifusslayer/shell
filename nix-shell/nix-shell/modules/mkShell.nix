# Собирает финальный devShell из модулей.
# Вызывается из flake.nix (и из shell.nix для не-flake пользователей).
{ pkgs, lib, cfg }:

let
  aliases = import ./aliases.nix;
  packages = import ./packages.nix { inherit pkgs lib cfg; };
  shell = import ./shells.nix { inherit pkgs lib cfg aliases; };
in
pkgs.mkShell {
  inherit packages;
  inherit (shell) shellHook;
}
