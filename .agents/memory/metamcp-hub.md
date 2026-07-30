---
name: MetaMCP hub rules
description: Правила конфигурации MetaMCP MCP-агрегатора — критичные gotchas
---

## Критичные правила

1. **APP_URL = реальный IP/hostname, не localhost** — MetaMCP жёстко валидирует CORS. `localhost` → CORS errors на всех агентах.

2. **Streamable HTTP `/mcp`, не SSE `/sse`** — в hermes-agent открытый баг: SSE теряет session ID → `Missing session ID`. OpenCode тоже нестабилен с SSE. `/mcp` надёжнее для обоих.

3. **Отдельный Postgres** — `metamcp-pg` изолированный контейнер, не реиспользует боевой кластер.

## Расположение конфигов

- Ansible роль: `infra/ansible/roles/metamcp/`
- Standalone compose (без Ansible): `mcp-hub/`
- Шаблоны агентов: `mcp-hub/agents/*.example`

**Why:** Hermes-agent баг подтверждён в NousResearch/hermes-agent issues (открыт с мая).
