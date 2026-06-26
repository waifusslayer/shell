# Гайд: установка и запуск nix-shell на бастион-сервере

---

## Часть 1 — Подготовка (делается один раз администратором)

### Шаг 1. Установить зависимости

```bash
sudo apt update
sudo apt install -y curl xz-utils git
```

### Шаг 2. Установить Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
```

Во время установки согласиться на всё (Enter / yes).  
После завершения — перезапустить терминал:

```bash
exec "$SHELL" -l
```

Проверить:

```bash
nix --version
# должно вывести: nix (Nix) 2.x.x
```

### Шаг 3. Создать GitLab OAuth Application (для kubelogin)

> Нужен доступ к GitLab с правами администратора группы или инстанса.

1. Открыть GitLab → **Admin Area → Applications** (или Group → Settings → Applications)
2. Нажать **New application**
3. Заполнить:
   - **Name:** `bastion-kubelogin`
   - **Redirect URI:** `http://localhost` (формально нужен, но использоваться не будет)
   - **Scopes:** поставить галки `openid`, `profile`, `read_user`
   - **Confidential:** можно оставить включённым
4. Нажать **Save application**
5. Скопировать **Application ID** и **Secret** — они понадобятся в следующем шаге

### Шаг 4. Создать конфиг окружения на бастионе

```bash
sudo nano /etc/profile.d/devshell.sh
```

Вставить и заменить значения на свои:

```bash
# GitLab — базовый URL корпоративного инстанса (без слеша на конце)
export DEVSHELL_GITLAB_URL=https://gitlab.example.com

# Время кеша токена: 28800 = 8 часов (потом при входе снова спросит PAT)
export DEVSHELL_AUTH_TTL=28800

# OAuth Application из шага 3
export DEVSHELL_KUBE_OIDC_CLIENT=ваш-application-id
export DEVSHELL_KUBE_OIDC_SECRET=ваш-secret

# Путь GitLab-группы девопсов (именно путь, не название)
# Пример: если группа на https://gitlab.example.com/mycompany/devops
# то значение: mycompany/devops
export DEVSHELL_KUBE_GROUP=mycompany/devops
```

Применить без перелогина:

```bash
source /etc/profile.d/devshell.sh
```

### Шаг 5. Склонировать репозиторий

```bash
git clone <url-репозитория> ~/devops-shell
chmod +x ~/devops-shell/enter.sh
chmod +x ~/devops-shell/modules/auth.sh
chmod +x ~/devops-shell/modules/kubeauth.sh
```

### Шаг 6. Положить kubeconfig на бастион

У каждого пользователя должен быть kubeconfig в `~/.kube/config`.  
Если kubeconfig один на всю команду — скопировать его каждому:

```bash
mkdir -p ~/.kube
cp /path/to/kubeconfig ~/.kube/config
chmod 600 ~/.kube/config
```

> После того как kubelogin пропишет OIDC credentials через `enter.sh`,
> обновить user в нужном контексте:
> ```bash
> kubectl config set-context <имя-контекста> --user=gitlab-oidc-<твой-username>
> ```
> Это делается один раз. Имя user`а скрипт подскажет при первом входе.

---

## Часть 2 — Что нужно сделать каждому пользователю

### Шаг 7. Создать GitLab Personal Access Token

1. Открыть GitLab → правый верхний угол → **Edit profile**
2. В левом меню → **Access Tokens**  
   Прямая ссылка: `https://gitlab.example.com/-/user_settings/personal_access_tokens`
3. Нажать **Add new token**
4. Заполнить:
   - **Token name:** `bastion-devshell` (любое)
   - **Expiration date:** оставить пустым (без срока) или поставить дату
   - **Scopes:** поставить галки `read_user` и `read_api`
5. Нажать **Create personal access token**
6. **Скопировать токен** (он показывается только один раз — `glpat-xxxxxxxxxxxx`)

### Шаг 8. Первый вход в шелл

```bash
~/devops-shell/enter.sh
```

Что произойдёт:

```
┌──────────────────────────────────────────────────────────┐
│           DevShell — GitLab аутентификация               │
│                                                          │
│  Создай PAT: https://gitlab.example.com/-/user_settings/personal_access_tokens
│  Нужные scopes: read_user, read_api                      │
└──────────────────────────────────────────────────────────┘

  GitLab Personal Access Token: (вводишь токен — не отображается)
  Проверяю токен... OK
  Проверяю членство в группе 'mycompany/devops'... ✓
  ✓ kubectl OIDC настроен для @username
    Обновлено контекстов: 1

  ✓ Добро пожаловать, Иван Иванов! (@ivan.ivanov)

✓ DevOps dev shell готов, Иван Иванов! shell: zsh, k8s: true, aws: true
```

После этого ты внутри шелла. Проверить kubectl:

```bash
kubectl get nodes
# Должно вернуть список нод без открытия браузера
```

### Шаг 9. Последующие входы

```bash
~/devops-shell/enter.sh
```

Пока кеш не истёк (8 часов по умолчанию) — токен не спрашивается:

```
  ✓ Привет, Иван Иванов! (сессия активна, кеш свежий)

  GitLab PAT для kubectl OIDC: (вводишь токен)
```

> **Почему PAT всё равно спрашивается для kubectl?**  
> Кеш хранит только имя пользователя, но не сам токен (из соображений безопасности —
> токен никогда не пишется на диск). Для kubelogin токен нужен в памяти при каждом входе.  
> Если kubectl не нужен — убери `DEVSHELL_KUBE_OIDC_CLIENT` из конфига, тогда второго запроса не будет.

---

## Часть 3 — Дополнительные команды

### Выйти из шелла

```bash
exit
```

### Войти с другим шеллом (без правки config.nix)

```bash
~/devops-shell/enter.sh .#fish
~/devops-shell/enter.sh .#bash
~/devops-shell/enter.sh .#zsh
```

### Сбросить кеш аутентификации вручную

```bash
rm -f /tmp/.devshell-auth-$USER
```

### Посмотреть текущий kubeconfig контекст

```bash
kubectl config get-contexts
```

### Назначить OIDC-пользователя контексту вручную

```bash
kubectl config set-context <имя-контекста> --user=gitlab-oidc-<твой-username>
```

---

## Быстрая шпаргалка

| Действие | Команда |
|---|---|
| Войти в шелл | `~/devops-shell/enter.sh` |
| Выйти | `exit` |
| Сбросить кеш auth | `rm /tmp/.devshell-auth-$USER` |
| Проверить kubectl | `kubectl get nodes` |
| Сменить контекст | `kubectx <имя>` |
| Сменить namespace | `kubens <имя>` |
| Создать новый PAT | `https://gitlab.example.com/-/user_settings/personal_access_tokens` |
