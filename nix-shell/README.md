# DevOps Environment — Nix Dev Shell

Декларативное окружение DevOps-инженера в виде **nix dev shell** (`nix develop`).
Работает полностью в userspace и **ничего не устанавливает в HOME постоянно** —
пакеты доступны в `PATH` только пока ты внутри шелла, на выходе всё исчезает.

Ниже — установка с нуля на **Ubuntu 26.04**.

---

## 1. Подготовка системы

Обнови пакеты и поставь зависимости установщика Nix:

```bash
sudo apt update
sudo apt install -y curl xz-utils git
```

> `curl` и `xz-utils` нужны установщику Nix, `git` — для клонирования репозитория.

---

## 2. Установка Nix

Рекомендуемый способ — установщик Determinate Systems: он ставит
**multi-user** (демон), сразу включает flakes и корректно работает с systemd
в Ubuntu.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install
```

Во время установки согласись на создание `/nix` и системного демона.
После завершения **перезапусти терминал** (или открой новую сессию), чтобы
подхватился профиль Nix:

```bash
exec "$SHELL" -l
```

Проверь, что Nix доступен:

```bash
nix --version
# nix (Nix) 2.x.x
```

<details>
<summary>Альтернатива: официальный установщик</summary>

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

После установки официальным способом flakes нужно включить вручную:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

</details>

---

## 3. Клонирование репозитория

```bash
git clone <url-репозитория> ~/dotfiles
cd ~/dotfiles
```

---

## 4. Настройка под себя

Открой `config.nix` и отредактируй флаги:

```nix
{
  preferredShell = "zsh";   # zsh | fish | bash | ksh
  enableK8s      = true;    # kubectl, helm, krew и т.д.
  enableAws      = true;    # aws-cli, rclone
  enableHelix    = false;   # редактор helix (опционально)
}
```

> По умолчанию стоит `zsh`. Если не уверен — оставь как есть.

---

## 5. Вход в окружение

```bash
nix develop
```

или через удобный скрипт (он сам включит flakes, если вдруг не включены):

```bash
chmod +x enter.sh
./enter.sh
```

При первом запуске Nix скачает все пакеты — это займёт несколько минут.
Последующие запуски работают мгновенно из кеша.

Выход из окружения — `exit` или `Ctrl-D`.

---

## 6. Проверка

```bash
kubectl version --client
helm version
k get nodes   # = kubectl get nodes
ll            # = eza -la --icons
```

---

## Что входит

| Категория      | Инструменты                                                                                  |
| -------------- | -------------------------------------------------------------------------------------------- |
| **Kubernetes** | kubectl, kubectx, kubens, kubecm, argocd, helm, kustomize, krew + плагины (stern, neat, tree, access-matrix, ctx, ns, images) |
| **Cloud**      | aws-cli v2, rclone                                                                           |
| **Утилиты**    | git, fzf, ripgrep, bat, eza, jq, yq, curl, rsync и др.                                       |
| **Шеллы**      | zsh (default), fish, bash, ksh — с completions и алиасами                                    |
| **Редакторы**  | neovim (default), vim, nano, helix (опционально)                                            |
| **Промпт**     | Starship — с kubernetes-контекстом (zsh/bash/fish; для ksh — простой prompt)                |
| **История**    | Atuin — единое хранилище истории (данные в `~/.local/share/atuin`)                          |

---

## Переключение шелла на лету

Не редактируя `config.nix`:

```bash
nix develop .#zsh
nix develop .#bash
nix develop .#fish
nix develop .#ksh
```

---

## Без flakes

Если flakes по какой-то причине недоступны:

```bash
nix-shell
```

`shell.nix` соберёт то же окружение через классический `nix-shell`.

---

## Автоматический вход (direnv)

С установленными `direnv` и `nix-direnv` окружение будет подниматься само
при `cd` в каталог:

```bash
direnv allow
```

---

## Обновление версий пакетов

```bash
cd ~/dotfiles
nix flake update    # обновит flake.lock до свежих nixpkgs
nix develop          # пересоберёт окружение с новыми версиями
```

---

## Kubeconfig, SSH, AWS

Не трогаются: `~/.kube/config`, `~/.ssh/`, `~/.aws/` читаются из HOME как обычно.
`KUBECONFIG` указывает на `~/.kube/config` (можно переопределить своей
переменной до входа в шелл).

Несколько kubeconfig-ов удобно вести через `kubecm`:

```bash
kubecm add -f ~/my-cluster.yaml
ktx   # сменить контекст
kns   # сменить namespace
```

---

## Пользовательские оверрайды

Свои настройки клади в HOME — они подхватятся автоматически и никогда не
перезаписываются:

| Шелл   | Файл                          |
| ------ | ----------------------------- |
| zsh    | `~/.config/zsh/extra.zsh`     |
| bash   | `~/.config/bash/extra.bash`   |
| fish   | `~/.config/fish/extra.fish`   |
| ksh    | `~/.config/ksh/extra.kshrc`   |
| neovim | `~/.config/nvim/init.lua`     |
| helix  | `~/.config/helix/config.toml` |

---

## Полезные алиасы

| Алиас | Команда                |
| ----- | ---------------------- |
| `k`   | kubectl                |
| `kg`  | kubectl get            |
| `kd`  | kubectl describe       |
| `kl`  | kubectl logs           |
| `ke`  | kubectl exec -it       |
| `kns` | kubens                 |
| `ktx` | kubectx                |
| `ll`  | eza -la --icons        |
| `gc`  | nix-collect-garbage -d |

---

## Добавить новый инструмент

1. Найди пакет: `nix search nixpkgs <название>`
2. Добавь в нужный список в `modules/packages.nix`:

```nix
core = with pkgs; [
  ...
  <новый-пакет>
];
```

3. Перезайди: `exit`, затем `nix develop`.

---

## Структура проекта

```
.
├── flake.nix              # точка входа, devShells (default + по шеллам)
├── shell.nix              # фоллбэк для nix-shell (без flakes)
├── config.nix             # ← редактируй флаги здесь
├── enter.sh               # удобный вход (включает flakes)
├── .envrc                 # авто-вход через direnv
├── assets/
│   ├── starship.toml      # конфиг промпта
│   └── nanorc             # конфиг nano
└── modules/
    ├── mkShell.nix        # сборка devShell
    ├── packages.nix       # выбор пакетов по флагам
    ├── aliases.nix        # общие алиасы
    └── shells.nix         # генерация rc-файлов + launcher shellHook
```

---

## Возможные проблемы

**`error: experimental Nix feature 'flakes' is not enabled`**

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

(`enter.sh` делает это автоматически.)

---

**`nix: command not found` после установки**

Перезапусти терминал или подгрузи профиль вручную:

```bash
. /etc/profile.d/nix.sh
# или
exec "$SHELL" -l
```

---

**Демон Nix не запущен**

```bash
sudo systemctl status nix-daemon
sudo systemctl enable --now nix-daemon
```

---

## GitLab PAT аутентификация (для бастион-серверов)

При входе через `./enter.sh` шелл может запросить GitLab Personal Access Token для идентификации пользователя. Это не влияет на доступ к самому бастиону (он управляется SSH), но позволяет персонализировать окружение под конкретного юзера.

### Настройка на сервере

Создай файл `/etc/profile.d/devshell.sh`:

```bash
# GitLab URL корпоративного инстанса (без слеша на конце)
export DEVSHELL_GITLAB_URL=https://gitlab.example.com

# Время кеша токена в секундах (28800 = 8 часов; 0 = спрашивать каждый раз)
export DEVSHELL_AUTH_TTL=28800
```

После этого `source /etc/profile.d/devshell.sh` или перелогиниться.

### Что нужно пользователям

Создать PAT в GitLab: **User Settings → Access Tokens → Add new token**

- Scope: `read_user` (минимально необходимый)
- Expiration: на своё усмотрение (рекомендуется без истечения или на год)

### Как это работает

1. Первый `./enter.sh` — запрашивает токен, валидирует через GitLab API, кеширует username в `/tmp/.devshell-auth-$USER`
2. Повторные входы в течение TTL — без запроса, берёт из кеша
3. После ребута сервера или истечения TTL — снова спросит токен

### Отключить аутентификацию

Просто не задавай `DEVSHELL_GITLAB_URL` — если переменная не установлена, auth-шаг пропускается.
