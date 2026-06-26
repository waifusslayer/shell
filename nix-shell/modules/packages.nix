# Список пакетов devShell в зависимости от флагов из config.nix.
# Аналог modules/core-utils.nix + kubernetes.nix + cloud.nix + editors.nix,
# но вместо home.packages — обычный список для mkShell.
{ pkgs, lib, cfg }:

let
  # ── Базовые утилиты (эквивалент busybox, отдельными пакетами) ──────────────
  core = with pkgs; [
    coreutils # ls, cp, mv, cat, …
    findutils # find, xargs
    diffutils # diff, cmp, patch
    gnugrep
    gnused
    gawk
    gnutar
    gzip
    bzip2
    xz
    which
    procps # ps, top, kill

    curl
    wget
    rsync

    fzf # fuzzy finder
    ripgrep # rg
    fd # замена find
    bat # замена cat
    eza # замена ls
    jq
    yq-go

    git
    git-lfs

    less
    tree
    unzip
    zip

    starship # промпт
    atuin # история шеллов
  ];

  # ── Kubernetes ─────────────────────────────────────────────────────────────
  k8s = with pkgs; [
    kubectl
    kubectx # содержит kubectx и kubens
    kubecm
    argocd
    helm
    kustomize
    krew
    kubelogin-oidc # kubectl oidc-login — device/password flow для бастиона
  ];

  # ── Cloud ─────────────────────────────────────────────────────────────────
  cloud = with pkgs; [
    awscli2
    rclone
  ];

  # ── Редакторы ────────────────────────────────────────────────────────────
  editors = with pkgs; [
    neovim
    vim
    nano
  ] ++ lib.optional cfg.enableHelix pkgs.helix;

  # ── Сам шелл + его плагины ──────────────────────────────────────────────────
  # bashInteractive нужен всегда: nix develop заходит в bash, а из него мы
  # уже exec-аем в выбранный шелл.
  shellPkgs = with pkgs;
    [ bashInteractive ]
    ++ lib.optionals (cfg.preferredShell == "zsh") [
      zsh
      zsh-autosuggestions
      zsh-syntax-highlighting
      zsh-completions
    ]
    ++ lib.optional (cfg.preferredShell == "fish") fish
    ++ lib.optional (cfg.preferredShell == "ksh") ksh;
in
core
++ lib.optionals cfg.enableK8s k8s
++ lib.optionals cfg.enableAws cloud
++ editors
++ shellPkgs

