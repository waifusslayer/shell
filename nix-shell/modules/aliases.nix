# Общие алиасы для всех шеллов.
# Раньше жили в modules/shells/common.nix как config.custom.shellAliases —
# теперь просто attrset, который читают генераторы rc-файлов в shells.nix.
#
# Примечание: алиасы home-manager (hms / hmsb) убраны — в dev shell нет
# "switch", вход в окружение это просто `nix develop`.
{
  # ── Kubernetes ──────────────────────────────────────────────────────────
  k = "kubectl";
  kg = "kubectl get";
  kd = "kubectl describe";
  kl = "kubectl logs";
  ke = "kubectl exec -it";
  kns = "kubens";
  ktx = "kubectx";
  kcm = "kubecm";

  # ── Git ─────────────────────────────────────────────────────────────────
  gs = "git status";
  gp = "git pull";
  gP = "git push";
  gl = "git log --oneline --graph";

  # ── Файловая система ──────────────────────────────────────────────────────
  ll = "eza -la --icons";
  la = "eza -a --icons";
  lt = "eza --tree --icons";

  # ── Nix ─────────────────────────────────────────────────────────────────
  gc = "nix-collect-garbage -d";
}
