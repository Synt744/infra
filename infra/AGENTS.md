# AGENTS.md — Инструкция для AI-агентов

Этот файл — авторитетный источник правил для агентов, работающих с этим репозиторием.  
Прочитай его полностью перед тем как редактировать любой файл.

---

## Что это за проект

Ansible Infrastructure as Code для Debian-рабочей станции.  
После чистой установки Debian — `bash scripts/bootstrap.sh` → полностью готовая система.

Репозиторий живёт в `infra/` внутри pnpm-монорепы.

---

## Единственный источник истины

| Что | Где |
|---|---|
| Все переменные | `ansible/group_vars/all/main.yml` |
| Все секреты | `ansible/group_vars/all/vault.yml` (зашифровано, **не читай, не создавай**) |
| Список ролей и порядок | `ansible/playbooks/workstation.yml` |
| Профили машин | `profiles/*.yml` |
| Шаблон секретов | `ansible/group_vars/all/vault.yml.example` |

---

## Правила редактирования

### Переменные
- Все новые переменные добавляются **только** в `group_vars/all/main.yml`
- Defaults в роли — только если нужен fallback, отличный от group_vars
- Никогда не хардкоди пути, порты, имена пользователей, IP — только `{{ переменная }}`
- Секреты в шаблонах ссылаются на `vault_*` переменные (например, `{{ vault_metamcp_postgres_password }}`)

### Роли
- Одна роль = одна область ответственности
- Каждая роль содержит: `tasks/main.yml`, `defaults/main.yml`, `meta/main.yml`
- Шаблоны — в `templates/`, handlers — в `handlers/main.yml`
- Первая строка каждого YAML-файла — `---`
- Комментарий `# Managed by Ansible — не редактируй вручную` в каждом шаблоне
- Зависимости роли — в `meta/main.yml` → `dependencies:`

### Ansible best practices (обязательно)
- Используй `ansible.builtin.*` для стандартных модулей (не `apt:`, а `ansible.builtin.apt:`)
- Используй `notify` → handlers вместо безусловных `state: restarted`
- Используй `changed_when: true/false` где нужно
- Не используй `shell:` или `command:` если есть специализированный модуль
- Не используй `curl | sh` если есть официальный apt/pip репозиторий
- Добавляй `tags:` к каждой задаче

### Docker стеки
- Compose-файлы — в `roles/<name>/templates/docker-compose.yml.j2`
- `.env` файлы — в `roles/<name>/templates/.env.j2`
- Ansible только: создаёт директории → разворачивает шаблоны → `docker compose up`
- Не создавай контейнеры вручную через `docker_container` модуль

### Профили
- Профиль = набор `install_*: true/false` переменных
- Не добавляй логику в профили — только переменные
- Новая машина = новый профиль, не изменение существующих

---

## Что НЕЛЬЗЯ делать

- ❌ Читать или создавать `ansible/group_vars/all/vault.yml` (содержит секреты)
- ❌ Хардкодить пароли, токены, IP-адреса в любых файлах
- ❌ Редактировать `artifact.toml` напрямую
- ❌ Добавлять логику в `playbooks/workstation.yml` — только роли и теги
- ❌ Создавать огромные плейбуки вместо ролей
- ❌ Добавлять зависимость одной роли от другой, минуя `meta/main.yml`
- ❌ Писать `curl | sh` установки там, где есть официальный пакетный менеджер

---

## Как добавить новый компонент

### Новый Docker сервис (например, Homepage)

```
1. Создать roles/homepage/
   ├── tasks/main.yml        — создать dirs, deploy templates, docker compose up
   ├── defaults/main.yml     — homepage_version, homepage_port, homepage_data_dir
   ├── handlers/main.yml     — Restart Homepage
   ├── templates/
   │   ├── docker-compose.yml.j2
   │   └── .env.j2
   └── meta/main.yml         — dependencies: [docker]

2. Добавить в group_vars/all/main.yml:
   install_homepage: true
   homepage_version: "latest"
   homepage_port: 3000
   homepage_data_dir: "{{ data_dir }}/homepage"

3. Добавить в ansible/playbooks/workstation.yml:
   - role: homepage
     tags: [docker, homepage]
     when: install_homepage | default(false)

4. Добавить переключатель в profiles/*.yml по необходимости
```

### Новый MCP-сервер в MetaMCP

MCP-серверы добавляются через MetaMCP UI, не через Ansible.  
Задокументируй в `docs/` как установить новый сервер через UI.  
Если нужна Ansible-роль (для standalone stdio-сервера), создай её по аналогии с ролью `hermes`.

### Новый AI-агент

```
1. Создать roles/<agentname>/
2. В meta/main.yml: dependencies: [ai]
3. Добавить install_<agentname>: true/false в group_vars и profiles
```

---

## Валидация перед завершением задачи

Перед тем как считать задачу выполненной, проверь:

- [ ] Нет захардкоженных значений (пути, порты, имена, IP)
- [ ] Все новые переменные в `group_vars/all/main.yml`
- [ ] Если добавлена роль — есть `meta/main.yml` с `dependencies`
- [ ] Если добавлен секрет — добавлен в `vault.yml.example` с `CHANGE_ME`
- [ ] Каждый шаблон содержит `# Managed by Ansible` в первой строке
- [ ] Каждая задача имеет `tags:`
- [ ] Handlers используются вместо безусловных restart
- [ ] `ansible.builtin.*` namespace используется для стандартных модулей
- [ ] `.gitignore` покрывает новые секретные файлы (если добавлены)

---

## Структура зависимостей ролей

```
common  ←  packages ←  git
        ←  ssh      ←  security  ←  firewall
        ←  network
        ←  docker   ←  dockge
                    ←  metamcp
        ←  fonts    ←  kde
        ←  flatpak
        ←  obsidian
        ←  backup
        ←  updates
        ←  ai       ←  hermes
                    ←  opencode
```

---

## Ключевые архитектурные решения

Подробнее в `docs/architecture.md`. Коротко:

1. **MetaMCP вместо mcp-proxy** — агрегация нескольких stdio-серверов в один endpoint
2. **Streamable HTTP `/mcp` не SSE** — hermes-agent баг на SSE (теряет session ID)
3. **APP_URL = реальный IP** — MetaMCP валидирует CORS, localhost не работает
4. **Restic для бэкапа** — нативная дедупликация, шифрование, официальный Debian пакет
5. **gocryptfs для Obsidian** — FUSE, прозрачное шифрование, нет накладных расходов CryFS на метаданные
6. **pipx для Python инструментов** — изолированные окружения, без system-wide загрязнения
