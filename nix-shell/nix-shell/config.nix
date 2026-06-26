# Пользовательские флаги окружения.
# Это эквивалент блока `custom` из старого home.nix.
# Меняй значения под себя — других nix-файлов трогать не нужно.
#
# Можно также переопределить шелл на лету, не редактируя файл:
#   nix develop .#fish
#   nix develop .#bash
{
  preferredShell = "zsh";   # zsh | fish | bash | ksh
  enableK8s      = true;    # kubectl, kubectx, kubecm, argocd, helm, kustomize, krew + плагины
  enableAws      = true;    # aws-cli v2, rclone
  enableHelix    = false;   # редактор helix (опционально)
}
