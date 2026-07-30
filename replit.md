# MCP Hub

Самохостинговый агрегатор MCP-инструментов на базе MetaMCP. Несколько stdio-серверов (memory, puppeteer и др.) → один Streamable HTTP/SSE endpoint с Bearer-аутентификацией для OpenCode и Hermes.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — запустить API-сервер (порт 5000)
- `pnpm run typecheck` — полный typecheck по всем пакетам
- `pnpm run build` — typecheck + сборка всех пакетов
- `pnpm --filter @workspace/api-spec run codegen` — перегенерировать API-хуки из OpenAPI-спека
- `pnpm --filter @workspace/db run push` — применить изменения схемы БД (dev only)
- Required env: `DATABASE_URL` — строка подключения к Postgres

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)
- MCP Hub: MetaMCP (Docker Compose) в `mcp-hub/`

## Where things live

- `mcp-hub/` — Docker Compose стек MetaMCP + конфиги агентов + инструкции
- `mcp-hub/README.md` — инструкция для человека (пошаговый деплой)
- `mcp-hub/AGENTS.md` — инструкция для агентов (архитектурные решения, правила правок)
- `artifacts/api-server/` — Express API-сервер
- `artifacts/mockup-sandbox/` — Canvas/дизайн-окружение

## Architecture decisions

- **MetaMCP вместо mcp-proxy/supergateway** — прокси пробрасывает только один stdio-сервер без агрегации; MetaMCP собирает несколько тулов в один endpoint.
- **Изолированный Postgres** — `metamcp-pg` отдельный контейнер, не трогает боевой кластер.
- **Streamable HTTP `/mcp` вместо SSE `/sse`** — в hermes-agent открытый баг на SSE (теряет session ID); `/mcp` надёжнее для обоих агентов.
- **`APP_URL` — реальный IP, не localhost** — MetaMCP валидирует CORS по этому URL.

## Product

Инфраструктурный хаб: общая память и инструменты для агентов OpenCode и Hermes через единый авторизованный MCP-endpoint.

## User preferences

_Populate as you build._

## Gotchas

- `APP_URL` в `.env` должен быть реальным IP/hostname, не `localhost` — иначе CORS-ошибки.
- Используй `/mcp` endpoint, не `/sse` — баг в hermes-agent на SSE-транспорте.
- Не трогай `.env` — только `.env.example`.

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
- `mcp-hub/AGENTS.md` — правила для агентов по работе с MCP-хабом
