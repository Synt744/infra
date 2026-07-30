# Infra — Infrastructure as Code

Полностью воспроизводимая Debian-рабочая станция на Ansible + Docker.  
Один `bootstrap.sh` после чистой установки → полностью готовая система.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — API-сервер (порт 5000)
- `pnpm run typecheck` — полный typecheck всех пакетов
- `pnpm run build` — typecheck + сборка
- `pnpm --filter @workspace/api-spec run codegen` — перегенерировать API-хуки
- `pnpm --filter @workspace/db run push` — применить схему БД (dev only)
- Required env: `DATABASE_URL` — строка подключения к Postgres

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5 / DB: PostgreSQL + Drizzle ORM
- IaC: Ansible 2.14+ / Profiles: workstation, laptop, server, raspberry
- MCP Hub: MetaMCP (Docker Compose)
- AI agents: Hermes + OpenCode → MetaMCP hub
- Desktop: KDE Plasma + Obsidian (gocryptfs vault)
- Backup: Restic + systemd timer

## Where things live

- `infra/` — весь Infrastructure as Code
  - `infra/scripts/bootstrap.sh` — точка входа после чистого Debian
  - `infra/scripts/update-system.sh` — обновление без потери данных
  - `infra/profiles/` — профили машин (workstation/laptop/server/raspberry)
  - `infra/ansible/roles/` — 19 модульных ролей
  - `infra/ansible/group_vars/all/main.yml` — единственный источник всех переменных
  - `infra/ansible/group_vars/all/vault.yml.example` — шаблон секретов
  - `infra/README.md` — инструкция для человека
  - `infra/AGENTS.md` — инструкция для агентов
  - `infra/docs/architecture.md` — архитектурные решения с обоснованиями
- `mcp-hub/` — standalone Docker Compose для MetaMCP (без Ansible)
- `artifacts/api-server/` — Express API-сервер
- `artifacts/mockup-sandbox/` — Canvas/дизайн-окружение

## Architecture decisions

- **Ansible + роли** — одна роль = одна область, идемпотентно, воспроизводимо
- **MetaMCP вместо mcp-proxy** — агрегация N stdio-серверов в один endpoint
- **`/mcp` не `/sse`** — hermes-agent баг на SSE-транспорте (Missing session ID)
- **gocryptfs для Obsidian** — быстрее CryFS, лучше совместим с Restic
- **Restic для бэкапа** — дедупликация, шифрование, sftp/S3, Debian пакет
- **`APP_URL` = реальный IP** — MetaMCP валидирует CORS по этому URL

## User preferences

_Populate as you build._

## Gotchas

- `APP_URL` в vault — реальный IP/hostname, не localhost
- Используй `/mcp` endpoint, не `/sse` (баг в hermes-agent)
- `vault.yml` в .gitignore — только `vault.yml.example` коммитится
- `ansible.builtin.*` namespace обязателен для всех стандартных модулей
- `scripts/bootstrap.sh` запускается от имени обычного пользователя, не root

## Pointers

- `infra/AGENTS.md` — правила для агентов (читай перед редактированием ролей)
- `infra/docs/architecture.md` — все архитектурные решения с обоснованиями
- `infra/ansible/group_vars/all/main.yml` — все переменные здесь
- See the `pnpm-workspace` skill for workspace structure and TypeScript details
