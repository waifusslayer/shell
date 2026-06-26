#!/usr/bin/env bash
# enter.sh — удобный вход в dev shell.
# Заменяет старый apply.sh: здесь нет "switch", вход — это просто nix develop.
#
# Использование:
#   ./enter.sh            # шелл из config.nix
#   ./enter.sh .#fish     # переопределить шелл

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Включаем flakes, если ещё не включены
NIX_CONF="$HOME/.config/nix/nix.conf"
if [ ! -f "$NIX_CONF" ] || ! grep -q "flakes" "$NIX_CONF" 2>/dev/null; then
    echo "==> Включаю nix flakes для пользователя…"
    mkdir -p "$HOME/.config/nix"
    echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
fi

# ── GitLab PAT аутентификация ─────────────────────────────────────────────────
# Запускаем до nix develop, чтобы получить DEVSHELL_USER до входа в шелл.
# Отключить: unset DEVSHELL_GITLAB_URL или DEVSHELL_AUTH_TTL=0
if [ -n "${DEVSHELL_GITLAB_URL:-}" ]; then
    # shellcheck source=modules/auth.sh
    source "$SCRIPT_DIR/modules/auth.sh"
fi

if [ "$#" -gt 0 ]; then
    exec nix develop "$@"
else
    exec nix develop
fi
