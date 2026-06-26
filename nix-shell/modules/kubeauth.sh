#!/usr/bin/env bash
# modules/kubeauth.sh — настройка kubeconfig для OIDC через GitLab PAT.
#
# Вызывается из modules/auth.sh после успешной валидации токена.
# Патчит kubeconfig пользователя так, чтобы kubelogin использовал
# grant-type=password (PAT как credentials) вместо browser flow.
#
# Переменные окружения (задаются в /etc/profile.d/devshell.sh):
#   DEVSHELL_GITLAB_URL        — базовый URL GitLab (уже задан в auth.sh)
#   DEVSHELL_KUBE_OIDC_CLIENT  — client_id OAuth приложения в GitLab
#   DEVSHELL_KUBE_OIDC_SECRET  — client_secret (если confidential app)
#   DEVSHELL_KUBE_GROUP        — путь GitLab-группы для проверки членства
#                                например: mycompany/devops
#
# Требует: kubelogin-oidc (kubectl-oidc_login) в PATH — ставится через nix.

set -euo pipefail

GITLAB_URL="${DEVSHELL_GITLAB_URL:-}"
OIDC_CLIENT="${DEVSHELL_KUBE_OIDC_CLIENT:-}"
OIDC_SECRET="${DEVSHELL_KUBE_OIDC_SECRET:-}"
GITLAB_GROUP="${DEVSHELL_KUBE_GROUP:-}"

# Из auth.sh уже экспортированы:
#   DEVSHELL_USER       — gitlab username
#   DEVSHELL_USER_NAME  — полное имя
#   DEVSHELL_GITLAB_PAT — PAT токен (экспортируем ниже в auth.sh)

# ── Проверка членства в группе ────────────────────────────────────────────────
_check_group_membership() {
  local token="$1" group="$2" username="$3"

  # GitLab API: GET /groups/:id/members/:user_id
  # Используем username как user_id (работает для личных аккаунтов)
  local encoded_group
  encoded_group=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=''))" "$group" 2>/dev/null \
    || echo "$group" | sed 's|/|%2F|g')

  local http_code
  http_code=$(curl -sf \
    --max-time 10 \
    -o /dev/null \
    -w "%{http_code}" \
    -H "PRIVATE-TOKEN: $token" \
    "${GITLAB_URL}/api/v4/groups/${encoded_group}/members/all/${username}" 2>/dev/null) || true

  if [[ "$http_code" == "200" ]]; then
    return 0
  else
    # Fallback: ищем по username среди участников
    local found
    found=$(curl -sf \
      --max-time 10 \
      -H "PRIVATE-TOKEN: $token" \
      "${GITLAB_URL}/api/v4/groups/${encoded_group}/members/all?per_page=100" 2>/dev/null \
      | grep -o "\"username\":\"${username}\"" | head -1) || true
    [[ -n "$found" ]]
  fi
}

# ── Патч kubeconfig: добавляем/обновляем user с oidc-login ───────────────────
_patch_kubeconfig() {
  local token="$1" username="$2"
  local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"

  if [[ ! -f "$kubeconfig" ]]; then
    echo "  ⚠ kubeconfig не найден (${kubeconfig}) — пропускаю настройку kubectl OIDC."
    echo "    Положи kubeconfig в ~/.kube/config и перезайди в шелл."
    return 0
  fi

  if [[ -z "$OIDC_CLIENT" ]]; then
    echo "  ⚠ DEVSHELL_KUBE_OIDC_CLIENT не задан — пропускаю настройку kubectl OIDC."
    return 0
  fi

  local issuer="${GITLAB_URL}"
  local oidc_user="gitlab-oidc-${username}"

  # Записываем credentials для kubelogin в kubeconfig.
  # grant-type=password: передаёт username + PAT как пароль напрямую,
  # без редиректа на браузер. GitLab принимает PAT как пароль в этом flow.
  kubectl config set-credentials "$oidc_user" \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-command=kubectl \
    --exec-arg=oidc-login \
    --exec-arg=get-token \
    --exec-arg="--oidc-issuer-url=${issuer}" \
    --exec-arg="--oidc-client-id=${OIDC_CLIENT}" \
    ${OIDC_SECRET:+--exec-arg="--oidc-client-secret=${OIDC_SECRET}"} \
    --exec-arg="--grant-type=password" \
    --exec-arg="--username=${username}" \
    --exec-arg="--password=${token}" \
    --exec-arg="--oidc-extra-scope=openid" \
    --exec-arg="--oidc-extra-scope=profile" \
    --exec-arg="--token-cache-dir=${HOME}/.kube/cache/oidc-tokens" \
    2>/dev/null

  # Обновляем все контексты, которые уже указывают на oidc-пользователя
  # (имя вида gitlab-oidc-* или явно заданного в DEVSHELL_KUBE_USER_PATTERN)
  local pattern="${DEVSHELL_KUBE_USER_PATTERN:-gitlab-oidc}"
  local contexts
  contexts=$(kubectl config get-contexts -o name 2>/dev/null) || true

  local patched=0
  while IFS= read -r ctx; do
    local current_user
    current_user=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"${ctx}\")].context.user}" 2>/dev/null) || true
    if [[ "$current_user" == *"$pattern"* ]]; then
      kubectl config set-context "$ctx" --user="$oidc_user" 2>/dev/null || true
      patched=$(( patched + 1 ))
    fi
  done <<< "$contexts"

  mkdir -p "${HOME}/.kube/cache/oidc-tokens"
  chmod 700 "${HOME}/.kube/cache/oidc-tokens"

  echo "  ✓ kubectl OIDC настроен для @${username} (grant-type=password)"
  if [[ "$patched" -gt 0 ]]; then
    echo "    Обновлено контекстов: ${patched}"
  else
    echo "    Подсказка: назначь пользователя вручную:"
    echo "    kubectl config set-context <ctx> --user=${oidc_user}"
  fi
}

# ── Точка входа ───────────────────────────────────────────────────────────────
devshell_kubeauth() {
  local token="${DEVSHELL_GITLAB_PAT:-}"
  local username="${DEVSHELL_USER:-}"

  if [[ -z "$token" || -z "$username" ]]; then
    # Вызван без контекста auth.sh — ничего не делаем
    return 0
  fi

  # Проверка членства в группе (если задана)
  if [[ -n "$GITLAB_GROUP" ]]; then
    echo -n "  Проверяю членство в группе '${GITLAB_GROUP}'..."
    if _check_group_membership "$token" "$GITLAB_GROUP" "$username"; then
      echo " ✓"
    else
      echo ""
      echo "✗ @${username} не является членом группы '${GITLAB_GROUP}'."
      echo "  Обратись к администратору GitLab для получения доступа."
      exit 1
    fi
  fi

  # Патчим kubeconfig
  _patch_kubeconfig "$token" "$username"
}

devshell_kubeauth
