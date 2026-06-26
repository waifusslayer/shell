# Генерация rc-файлов для каждого шелла + launcher shellHook.
#
# В отличие от home-manager, dev shell ничего не пишет в HOME. Все rc-файлы
# собираются в /nix/store, а нужный шелл запускается из shellHook через exec
# с указанием на сгенерированный rc. Это эквивалент:
#   - programs.<shell>.initContent / interactiveShellInit
#   - programs.starship / atuin
#   - home.file.".kshrc" / ".nanorc"
#   - home.sessionVariables
#   - home.activation.installKrewPlugins
{ pkgs, lib, cfg, aliases }:

let
  # ── Ассеты ────────────────────────────────────────────────────────────────
  starshipToml = ../assets/starship.toml;
  nanorc = ../assets/nanorc;

  # nano не читает env-переменную с конфигом — подсовываем через alias.
  allAliases = aliases // {
    nano = "nano --rcfile ${nanorc}";
  };

  # POSIX-шеллы: alias name='cmd'
  mkPosixAliases = a:
    lib.concatStringsSep "\n"
      (lib.mapAttrsToList (k: v: "alias ${k}='${v}'") a);

  # fish: alias name 'cmd'
  mkFishAliases = a:
    lib.concatStringsSep "\n"
      (lib.mapAttrsToList (k: v: "alias ${k} '${v}'") a);

  # krew-плагины (как в старом modules/kubernetes.nix)
  krewPlugins = [
    "stern"
    "neat"
    "tree"
    "access-matrix"
    "ctx"
    "ns"
    "images"
  ];

  # ── atuin: конфиг в store, история в HOME (~/.local/share/atuin) ───────────
  atuinDir = pkgs.runCommand "devshell-atuin-config" { } ''
    mkdir -p "$out"
    cat > "$out/config.toml" <<'EOF'
    auto_sync = false
    sync_address = ""
    update_check = false
    EOF
  '';

  # ── zsh rc ──────────────────────────────────────────────────────────────
  zshrc = pkgs.writeText "devshell-zshrc" ''
    # Сгенерировано nix devShell. Свои правки клади в ~/.config/zsh/extra.zsh
    export PATH="$HOME/.krew/bin:$PATH"

    eval "$(starship init zsh)"

    autoload -Uz compinit && compinit -u -d "$HOME/.zcompdump"

    source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
    fpath+=(${pkgs.zsh-completions}/share/zsh/site-functions)

    HISTFILE="$HOME/.zsh_history"
    HISTSIZE=50000
    SAVEHIST=50000
    setopt SHARE_HISTORY HIST_IGNORE_DUPS EXTENDED_HISTORY

    ${mkPosixAliases allAliases}

    if command -v kubectl &>/dev/null; then
      source <(kubectl completion zsh 2>/dev/null)
    fi
    command -v helm    &>/dev/null && source <(helm    completion zsh 2>/dev/null)
    command -v kubectx &>/dev/null && source <(kubectx completion zsh 2>/dev/null) || true
    command -v kubens  &>/dev/null && source <(kubens  completion zsh 2>/dev/null) || true
    command -v argocd  &>/dev/null && source <(argocd  completion zsh 2>/dev/null)

    [ -f "${pkgs.fzf}/share/fzf/completion.zsh"   ] && source "${pkgs.fzf}/share/fzf/completion.zsh"
    [ -f "${pkgs.fzf}/share/fzf/key-bindings.zsh" ] && source "${pkgs.fzf}/share/fzf/key-bindings.zsh"

    command -v atuin &>/dev/null && eval "$(atuin init zsh)"

    [ -f "$HOME/.config/zsh/extra.zsh" ] && source "$HOME/.config/zsh/extra.zsh"

    # syntax-highlighting обязательно последним
    source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
  '';

  # zsh читает $ZDOTDIR/.zshrc — кладём rc в каталог
  zshDir = pkgs.runCommand "devshell-zdotdir" { } ''
    mkdir -p "$out"
    cp ${zshrc} "$out/.zshrc"
  '';

  # ── bash rc ──────────────────────────────────────────────────────────────
  bashrc = pkgs.writeText "devshell-bashrc" ''
    # Сгенерировано nix devShell. Свои правки клади в ~/.config/bash/extra.bash
    export PATH="$HOME/.krew/bin:$PATH"

    eval "$(starship init bash)"

    HISTFILE="$HOME/.bash_history"
    HISTSIZE=50000
    HISTFILESIZE=50000
    HISTCONTROL=ignoredups:erasedups

    ${mkPosixAliases allAliases}

    if command -v kubectl &>/dev/null; then
      source <(kubectl completion bash 2>/dev/null)
    fi
    command -v helm    &>/dev/null && source <(helm    completion bash 2>/dev/null)
    command -v kubectx &>/dev/null && source <(kubectx completion bash 2>/dev/null) || true
    command -v kubens  &>/dev/null && source <(kubens  completion bash 2>/dev/null) || true
    command -v argocd  &>/dev/null && source <(argocd  completion bash 2>/dev/null)

    [ -f "${pkgs.fzf}/share/fzf/completion.bash"   ] && source "${pkgs.fzf}/share/fzf/completion.bash"
    [ -f "${pkgs.fzf}/share/fzf/key-bindings.bash" ] && source "${pkgs.fzf}/share/fzf/key-bindings.bash"

    [ -f "${pkgs.bash-preexec}/share/bash-preexec.sh" ] && source "${pkgs.bash-preexec}/share/bash-preexec.sh"
    command -v atuin &>/dev/null && eval "$(atuin init bash)"

    [ -f "$HOME/.config/bash/extra.bash" ] && source "$HOME/.config/bash/extra.bash"
  '';

  # ── fish rc ──────────────────────────────────────────────────────────────
  fishInit = pkgs.writeText "devshell-config.fish" ''
    # Сгенерировано nix devShell. Свои правки клади в ~/.config/fish/extra.fish
    set -gx PATH "$HOME/.krew/bin" $PATH

    starship init fish | source

    ${mkFishAliases allAliases}

    if command -q kubectl
      kubectl completion fish 2>/dev/null | source
    end
    command -q helm;   and helm   completion fish 2>/dev/null | source
    command -q argocd; and argocd completion fish 2>/dev/null | source

    ${pkgs.fzf}/bin/fzf --fish | source

    command -q atuin; and atuin init fish | source

    set -gx fish_history default

    function kctx
      kubectx (kubectx | fzf --prompt="context> ")
    end
    function kns-pick
      kubens (kubens | fzf --prompt="namespace> ")
    end

    test -f "$HOME/.config/fish/extra.fish"; and source "$HOME/.config/fish/extra.fish"
  '';

  # ── ksh rc ──────────────────────────────────────────────────────────────
  # ВАЖНО: starship не поддерживает ksh (нет `starship init ksh`) — в старом
  # репозитории это была скрытая ошибка. Здесь ставим простой prompt.
  kshrc = pkgs.writeText "devshell-kshrc" ''
    # Сгенерировано nix devShell. Свои правки клади в ~/.config/ksh/extra.kshrc
    export PATH="$HOME/.krew/bin:$HOME/.nix-profile/bin:$PATH"

    PS1='$PWD $ '

    export HISTFILE="$HOME/.ksh_history"
    export HISTSIZE=50000

    ${mkPosixAliases allAliases}

    command -v kubectl &>/dev/null && . <(kubectl completion bash 2>/dev/null)
    command -v helm    &>/dev/null && . <(helm    completion bash 2>/dev/null)
    command -v argocd  &>/dev/null && . <(argocd  completion bash 2>/dev/null)

    [ -f "${pkgs.fzf}/share/fzf/key-bindings.bash" ] && . "${pkgs.fzf}/share/fzf/key-bindings.bash"

    [ -f "$HOME/.config/ksh/extra.kshrc" ] && . "$HOME/.config/ksh/extra.kshrc"
  '';

  # ── Команда запуска выбранного шелла ──────────────────────────────────────
  launchCmd =
    if cfg.preferredShell == "zsh" then ''
      export ZDOTDIR=${zshDir}
      exec zsh -i
    ''
    else if cfg.preferredShell == "fish" then ''
      exec fish -C "source ${fishInit}"
    ''
    else if cfg.preferredShell == "ksh" then ''
      export ENV=${kshrc}
      exec ksh -i
    ''
    else ''
      exec bash --rcfile ${bashrc} -i
    '';

  # ── Установка krew-плагинов (был home.activation.installKrewPlugins) ───────
  # Запускается один раз: маркер ~/.krew/.devshell-plugins
  krewBlock = lib.optionalString cfg.enableK8s ''
    mkdir -p "$HOME/.krew"
    export PATH="$HOME/.krew/bin:$PATH"
    if [ ! -f "$HOME/.krew/.devshell-plugins" ] && [ -x "${pkgs.krew}/bin/kubectl-krew" ]; then
      echo "==> Устанавливаю krew-плагины (только при первом входе)…"
      "${pkgs.krew}/bin/kubectl-krew" install krew >/dev/null 2>&1 || true
      "${pkgs.krew}/bin/kubectl-krew" update      >/dev/null 2>&1 || true
      for p in ${lib.concatStringsSep " " krewPlugins}; do
        "${pkgs.krew}/bin/kubectl-krew" install "$p" >/dev/null 2>&1 || true
      done
      touch "$HOME/.krew/.devshell-plugins" 2>/dev/null || true
    fi
  '';

  # ── shellHook: запускается в bash, который поднимает nix develop ───────────
  shellHook = ''
    # Защита от повторного входа (например, nix develop внутри nix develop)
    if [ -n "''${__DEVSHELL_ACTIVE:-}" ]; then
      return 0 2>/dev/null || true
    fi
    export __DEVSHELL_ACTIVE=1

    # Глобальные переменные окружения (был home.sessionVariables)
    export EDITOR=nvim
    export VISUAL=nvim
    export KUBECONFIG="''${KUBECONFIG:-$HOME/.kube/config}"
    export STARSHIP_CONFIG="${starshipToml}"
    export ATUIN_CONFIG_DIR="${atuinDir}"
    export PATH="$HOME/.krew/bin:$PATH"

    ${krewBlock}

    if [ -n "''${DEVSHELL_USER_NAME:-}" ]; then
      echo "✓ DevOps dev shell готов, ''${DEVSHELL_USER_NAME}! shell: ${cfg.preferredShell}, k8s: ${lib.boolToString cfg.enableK8s}, aws: ${lib.boolToString cfg.enableAws}"
    else
      echo "✓ DevOps dev shell готов — shell: ${cfg.preferredShell}, k8s: ${lib.boolToString cfg.enableK8s}, aws: ${lib.boolToString cfg.enableAws}"
    fi

    # Передаём управление выбранному шеллу
    ${launchCmd}
  '';
in
{
  inherit shellHook;
}
