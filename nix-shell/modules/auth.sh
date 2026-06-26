#!/usr/bin/env bash
# modules/auth.sh — GitLab PAT аутентификация для бастион-сервера.
#
# Настройка через переменные окружения (задай в /etc/profile.d/devshell.sh):
#   DEVSHELL_GITLAB_URL        — базовый URL GitLab (без слеша на конце)
#   DEVSHELL_AUTH_TTL          — время кеша в секундах (default: 28800 = 8ч; 0 = каждый раз)
#   DEVSHELL_KUBE_OIDC_CLIENT  — client_id для kubelogin (если нужен kubectl OIDC)
#   DEVSHELL_KUBE_OIDC_SECRET  — client_secret (если confidential OAuth app)
#   DEVSHELL_KUBE_GROUP        — GitLab-группа для проверки доступа (напр: mycompany/devops)
#
# PAT нужен со scope: read_user (+ read_api если нужна проверка группы).
# PAT экспортируется как DEVSHELL_GITLAB_PAT только в память — в файл не пишется.

set -euo pipefail

GITLAB_URL="${DEVSHELL_GITLAB_URL:-https://gitlab.com}"
CACHE_TTL="${DEVSHELL_AUTH_TTL:-28800}"

# Кеш хранит только username|name — токен НИКОГДА не пишется на диск
CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/.devshell-auth-${USER}"

# ── Проверка кеша ─────────────────────────────────────────────────────────────
_cache_valid() {
  [[ "$CACHE_TTL" -eq 0 ]]  && return 1
  [[ -f "$CACHE_FILE" ]]    || return 1
  local age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  [[ "$age" -lt "$CACHE_TTL" ]]
}

_cache_read() { cat "$CACHE_FILE" 2>/dev/null; }

_cache_write() {
  echo "$1" > "$CACHE_FILE"
  chmod 600 "$CACHE_FILE"
}

# ── Валидация токена через GitLab API ─────────────────────────────────────────
_validate_token() {
  local token="$1"
  local resp http_code

  resp=$(curl -sf \
    --max-time 10 \
    -w "\n__HTTP_CODE__%{http_code}" \
    -H "PRIVATE-TOKEN: $token" \
    "${GITLAB_URL}/api/v4/user" 2>/dev/null) || {
    echo "✗ Не удалось подключиться к ${GITLAB_URL}. Проверь сеть." >&2
    return 1
  }

  http_code=$(echo "$resp" | grep -o '__HTTP_CODE__[0-9]*' | cut -c15-)
  local body
  body=$(echo "$resp" | sed '/__HTTP_CODE__/d')

  if [[ "$http_code" == "401" ]]; then
    echo "✗ Токен недействителен или истёк." >&2; return 1
  fi
  if [[ "$http_code" != "200" ]]; then
    echo "✗ GitLab вернул статус: ${http_code}." >&2; return 1
  fi

  local username name
  username=$(echo "$body" | grep -o '"username":"[^"]*"' | head -1 | cut -d'"' -f4)
  name=$(echo "$body"     | grep -o '"name":"[^"]*"'     | head -1 | cut -d'"' -f4)

  [[ -z "$username" ]] && { echo "✗ Не удалось получить username." >&2; return 1; }
  echo "${username}|${name}"
}

# ── Основная функция ──────────────────────────────────────────────────────────
devshell_auth() {
  local token=""

  if _cache_valid; then
    local cached cached_user cached_name
    cached=$(_cache_read)
    cached_user="${cached%%|*}"
    cached_name="${cached##*|}"
    echo ""
    echo "  ✓ Привет, ${cached_name:-$cached_user}! (сессия активна, кеш свежий)"
    echo ""
    export DEVSHELL_USER="$cached_user"
    export DEVSHELL_USER_NAME="${cached_name:-$cached_user}"

    # При кеше всё равно нужен токен для kubelogin — запрашиваем тихо
    if [[ -n "${DEVSHELL_KUBE_OIDC_CLIENT:-}" ]]; then
      read -r -s -p "  GitLab PAT для kubectl OIDC: " token
      echo ""
      export DEVSHELL_GITLAB_PAT="$token"
      # shellcheck source=modules/kubeauth.sh
      source "$(dirname "${BASH_SOURCE[0]}")/kubeauth.sh"
    fi
    return 0
  fi

  # ── Первый вход — запрашиваем токен ─────────────────────────────────────────
  echo ""
  echo "┌──────────────────────────────────────────────────────────┐"
  echo "│           DevShell — GitLab аутентификация               │"
  echo "│                                                          │"
  echo "│  Создай PAT: ${GITLAB_URL}/-/user_settings/personal_access_tokens"
  echo "│  Нужные scopes: read_user, read_api                      │"
  echo "└──────────────────────────────────────────────────────────┘"
  echo ""

  read -r -s -p "  GitLab Personal Access Token: " token
  echo ""

  [[ -z "$token" ]] && { echo "✗ Токен не введён." >&2; exit 1; }

  echo -n "  Проверяю токен..."
  local result
  result=$(_validate_token "$token") || exit 1
  echo " OK"

  local username="${result%%|*}"
  local name="${result##*|}"

  # username|name кешируется; сам токен — только в памяти процесса
  _cache_write "${username}|${name}"

  echo ""
  echo "  ✓ Добро пожаловать, ${name:-$username}! (@${username})"
  echo ""

  export DEVSHELL_USER="$username"
  export DEVSHELL_USER_NAME="${name:-$username}"
  export DEVSHELL_GITLAB_PAT="$token"

  # Проверка группы + настройка kubeconfig
  # shellcheck source=modules/kubeauth.sh
  source "$(dirname "${BASH_SOURCE[0]}")/kubeauth.sh"
}

devshell_auth
