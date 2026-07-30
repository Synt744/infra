# infra — Infrastructure as Code

Полностью воспроизводимая рабочая станция на Debian.  
После чистой установки достаточно запустить `bootstrap.sh` — и через несколько минут система готова к работе.

---

## Быстрый старт

```bash
# 1. Установи Debian, подключись к сети, залогинься
# 2. Запусти bootstrap
bash <(curl -fsSL https://YOUR_GIT_HOST/raw/main/scripts/bootstrap.sh)

# Или после ручного клонирования:
git clone https://YOUR_GIT_HOST/infra.git ~/infra
cd ~/infra
bash scripts/bootstrap.sh
```

Скрипт сам установит Ansible, спросит профиль и уйдёт работать.  
Ты можешь идти пить чай.

---

## Структура репозитория

```
infra/
├── scripts/
│   ├── bootstrap.sh          # Точка входа — первый запуск с нуля
│   └── update-system.sh      # Обновление инфраструктуры
│
├── profiles/                 # Профили машин
│   ├── workstation.yml       # Домашняя рабочая станция (полный набор)
│   ├── laptop.yml            # Ноутбук (backup включён, MetaMCP выключен)
│   ├── server.yml            # Headless сервер (без GUI)
│   └── raspberry.yml         # Raspberry Pi (минимальный набор)
│
├── ansible/
│   ├── playbooks/
│   │   └── workstation.yml   # Мастер-плейбук (оркестрация ролей)
│   ├── roles/                # Все роли (одна роль = одна область)
│   │   ├── common/           # База: locale, timezone, /opt dirs
│   │   ├── packages/         # Системные пакеты
│   │   ├── git/              # Git + ~/.gitconfig
│   │   ├── ssh/              # SSH ключи + hardening sshd
│   │   ├── network/          # NetworkManager
│   │   ├── docker/           # Docker CE
│   │   ├── dockge/           # Dockge UI для Docker стеков
│   │   ├── metamcp/          # MetaMCP — MCP-агрегатор
│   │   ├── kde/              # KDE Plasma
│   │   ├── fonts/            # Шрифты + Nerd Fonts
│   │   ├── flatpak/          # Flatpak + Flathub приложения
│   │   ├── obsidian/         # Obsidian + gocryptfs vault
│   │   ├── ai/               # Node.js, Python, uv, pipx
│   │   ├── hermes/           # Hermes AI agent
│   │   ├── opencode/         # OpenCode AI agent
│   │   ├── security/         # fail2ban, sysctl hardening
│   │   ├── firewall/         # UFW
│   │   ├── backup/           # Restic + systemd timer
│   │   └── updates/          # Unattended security upgrades
│   ├── group_vars/
│   │   └── all/
│   │       ├── main.yml      # ← Все переменные здесь. Единственный источник истины.
│   │       ├── vault.yml     # Секреты (зашифрован ansible-vault, не коммитится)
│   │       └── vault.yml.example  # Шаблон для vault.yml
│   └── inventories/
│       └── local/
│           └── hosts.yml     # Локальная установка (localhost)
│
├── docs/
│   └── architecture.md       # Архитектурные решения и обоснования
│
├── .ansible-lint             # Конфиг ansible-lint
├── .yamllint                 # Конфиг yamllint
└── .gitignore                # vault.yml и секреты исключены
```

---

## Первая настройка секретов

```bash
cd ~/infra

# 1. Создай vault.yml из шаблона
cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml

# 2. Заполни значения (git name/email, пароли для MetaMCP, токены MCP hub, ...)
nano ansible/group_vars/all/vault.yml

# 3. Зашифруй vault
ansible-vault encrypt ansible/group_vars/all/vault.yml

# Для редактирования позже:
ansible-vault edit ansible/group_vars/all/vault.yml
```

---

## Запуск отдельных ролей

```bash
# Применить только Docker
ansible-playbook -i ansible/inventories/local/hosts.yml \
  profiles/workstation.yml --tags docker --ask-vault-pass

# Применить MetaMCP
ansible-playbook -i ansible/inventories/local/hosts.yml \
  profiles/workstation.yml --tags metamcp --ask-vault-pass

# Dry-run (проверить, что изменится)
ansible-playbook -i ansible/inventories/local/hosts.yml \
  profiles/workstation.yml --check --diff --ask-vault-pass
```

---

## Обновление инфраструктуры

```bash
# Интерактивный (с подтверждением)
./scripts/update-system.sh

# Без подтверждений
./scripts/update-system.sh --yes

# Только конкретные роли
./scripts/update-system.sh --tags metamcp,docker

# Только dry-run
./scripts/update-system.sh --check
```

---

## Переключение компонентов

В `profiles/workstation.yml` любой компонент отключается одной переменной:

```yaml
install_metamcp: false     # выключить MetaMCP
install_obsidian: false    # выключить Obsidian
install_backup: true       # включить бэкап
```

---

## Проверка качества кода

```bash
# Lint всех ролей
cd ~/infra
ansible-lint ansible/

# Проверка YAML
yamllint ansible/

# Syntax check плейбука
ansible-playbook --syntax-check \
  -i ansible/inventories/local/hosts.yml \
  profiles/workstation.yml
```

---

## Добавление нового компонента

1. Создай новую роль: `ansible/roles/<name>/`
2. Добавь переменные в `group_vars/all/main.yml`
3. Добавь роль в `ansible/playbooks/workstation.yml`
4. Добавь переключатель `install_<name>: true/false`
5. При необходимости добавь в профили

Не меняй существующие роли — только добавляй новые.

---

## Зависимость ролей

```
common
├── packages
├── git
├── ssh
│   └── security
│       └── firewall
├── network
├── docker
│   ├── dockge
│   └── metamcp
├── fonts
│   └── kde
│       └── kde (зависит также от fonts)
├── flatpak
├── obsidian
├── backup
├── updates
└── ai
    ├── hermes
    └── opencode
```

---

## Следующие шаги (после стабилизации)

- [ ] Obsidian filesystem-сервер в MetaMCP namespace (через зашифрованный vault)
- [ ] Molecule тесты для ролей
- [ ] CI/CD через GitHub Actions (ansible-lint + syntax-check)
- [ ] Homepage dashboard стек в Dockge
