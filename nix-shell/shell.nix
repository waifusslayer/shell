# Фоллбэк для тех, у кого не включены flakes: `nix-shell`
# (для flake-пользователей основной путь — `nix develop`, см. flake.nix).
#
# Пинит nixpkgs тарболом. Для воспроизводимости можешь зафиксировать
# конкретный коммит и sha256.
let
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixpkgs-unstable.tar.gz";
  };
  pkgs = import nixpkgs { };
  lib = pkgs.lib;
  cfg = import ./config.nix;
in
import ./modules/mkShell.nix { inherit pkgs lib cfg; }
