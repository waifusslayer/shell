{
  description = "DevOps userspace environment as a nix dev shell (nix develop)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      userConfig = import ./config.nix;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      # `nix develop`            -> shell из config.nix
      # `nix develop .#fish`     -> переопределить шелл без правки файла
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = pkgs.lib;

          mkShellFor = override:
            import ./modules/mkShell.nix {
              inherit pkgs lib;
              cfg = userConfig // override;
            };
        in
        {
          default = mkShellFor { };
          zsh = mkShellFor { preferredShell = "zsh"; };
          bash = mkShellFor { preferredShell = "bash"; };
          fish = mkShellFor { preferredShell = "fish"; };
          ksh = mkShellFor { preferredShell = "ksh"; };
        });
    };
}
