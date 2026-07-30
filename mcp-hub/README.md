# MCP Hub — MetaMCP Self-Hosted Setup

Самохостинговый агрегатор MCP-инструментов на базе [MetaMCP](https://github.com/metatool-ai/metamcp).  
Несколько stdio-серверов (memory, puppeteer, scrapling и др.) → один SSE/HTTP endpoint с Bearer-аутентификацией.

---

## Структура файлов

```
mcp-hub/
├── docker-compose.yml          # Стек MetaMCP + Postgres
├── .env.example                # Шаблон переменных окружения
├── .env                        # Твои секреты (создаёшь сам, не коммитишь)
├── .gitignore
└── agents/
    ├── opencode.config.json.example   # Конфиг для OpenCode
    └── hermes.config.yaml.example     # Конфиг для Hermes
```

---

## Первый запуск

### 1. Подготовь окружение

```bash
cd /opt/stacks/mcp-hub

# Скопируй шаблон
cp .env.example .env
```

Открой `.env` и заполни три значения:

| Переменная | Что туда | Команда для генерации |
|---|---|---|
| `POSTGRES_PASSWORD` | Пароль Postgres | `openssl rand -hex 16` |
| `BETTER_AUTH_SECRET` | Секрет авторизации | `openssl rand -hex 32` |
| `APP_URL` | Реальный IP/hostname машины | — |

> ⚠️ `APP_URL` — **не** `localhost`. Это адрес, с которого будут стучаться агенты.  
> Пример: `http://192.168.1.42:12008`

### 2. Поднять стек

```bash
docker compose up -d

# Проверить, что всё живое
docker compose ps
docker compose logs -f app
```

### 3. Настрой через веб-UI (http://YOUR_HOST:12008)

Зайди в браузере, создай аккаунт.

**Шаг 1 — добавь MCP-серверы** (`MCP Servers → Add`):

```json
{ "type": "STDIO", "command": "npx", "args": ["-y", "@modelcontextprotocol/server-memory"] }
```
```json
{ "type": "STDIO", "command": "npx", "args": ["-y", "@modelcontextprotocol/server-puppeteer"] }
```

**Шаг 2 — создай Namespace** (`Namespaces → Add`):
- Имя: `core-tools`
- Добавь оба сервера из шага 1

**Шаг 3 — создай Endpoint** (`Endpoints → Add`):
- Имя: `hub`
- Привязать к namespace: `core-tools`
- Auth: включи API Key (Bearer-токен)
- Скопируй ключ вида `sk_mt_...`

Теперь у тебя два URL:
- **Streamable HTTP** (рекомендуется): `http://YOUR_HOST:12008/metamcp/hub/mcp`
- **SSE** (запасной): `http://YOUR_HOST:12008/metamcp/hub/sse`

---

## Подключение агентов

> ⚠️ **Используй `/mcp` (Streamable HTTP), не `/sse`!**  
> В `hermes-agent` открытый баг на SSE-транспорте: теряет session ID → `Missing session ID`.  
> У OpenCode тоже была нестабильность с SSE. `/mcp` надёжнее для обоих.

### OpenCode

Файл: `~/.config/opencode/config.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "hub": {
      "type": "remote",
      "url": "http://YOUR_HOST:12008/metamcp/hub/mcp",
      "headers": { "Authorization": "Bearer sk_mt_YOUR_KEY" },
      "enabled": true
    }
  }
}
```

### Hermes

Файл: `~/.hermes/config.yaml`

```yaml
mcp_servers:
  hub:
    url: "http://YOUR_HOST:12008/metamcp/hub/mcp"
    headers:
      Authorization: "Bearer sk_mt_YOUR_KEY"
```

---

## Добавление новых инструментов

Любой stdio-сервер добавляется через UI. Для инструментов без MCP-обвязки (например, Scrapling) — оборачиваешь в FastMCP STDIO-сервер и добавляешь так же.

---

## Обновление MetaMCP

```bash
docker compose pull
docker compose up -d
```

---

## Troubleshooting

| Проблема | Причина | Решение |
|---|---|---|
| CORS ошибки | `APP_URL` стоит `localhost` | Поставь реальный IP |
| `Missing session ID` | Используешь SSE в Hermes | Переключись на `/mcp` |
| Postgres не стартует | OOM (мало RAM) | Это отдельный PG, не трогает боевой кластер, но RAM нужна |
| MetaMCP не видит сервера | stdio-тул не установлен в контейнере | `npx` доустанавливает при первом запуске, подожди |

---

## Следующий шаг: Obsidian

После стабилизации хаба — подключить filesystem-сервер поверх расшифрованного вольта Obsidian как ещё один MCP-сервер в том же namespace `core-tools`.
