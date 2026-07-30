# MCP Hub — Agent Instructions

This document is for AI agents working on this repository.

## What This Project Is

A self-hosted MCP aggregator hub using [MetaMCP](https://github.com/metatool-ai/metamcp).  
Multiple stdio MCP servers (memory, puppeteer, etc.) → single Streamable HTTP / SSE endpoint with Bearer auth.

## Repository Layout

```
mcp-hub/
├── docker-compose.yml          # MetaMCP app + isolated Postgres
├── .env.example                # Required env vars (template)
├── .env                        # Actual secrets — never read or print this file
├── .gitignore
└── agents/
    ├── opencode.config.json.example   # OpenCode MCP client config
    └── hermes.config.yaml.example     # Hermes MCP client config
```

## Key Architecture Decisions

1. **MetaMCP over mcp-proxy / supergateway** — mcp-proxy only proxies a single stdio server per container with no aggregation. MetaMCP aggregates multiple stdio tools into one authenticated endpoint.

2. **Isolated Postgres** — `metamcp-pg` is a dedicated container. Do NOT reuse the host's production Postgres cluster.

3. **Streamable HTTP (`/mcp`) over SSE (`/sse`)** — hermes-agent has an open bug losing session IDs on SSE transport. OpenCode also had SSE instability. Use `/mcp` for both agents unless a specific client version explicitly requires SSE.

4. **`APP_URL` must be the real host IP/hostname** — MetaMCP validates requests against this URL for CORS. Setting it to `localhost` breaks all remote agent connections.

## Making Changes

### docker-compose.yml

- Do not change service names (`app`, `postgres`) — they are referenced in `DATABASE_URL` and `depends_on`.
- Do not add `network_mode: host` — the bridge network + `extra_hosts` handles `host.docker.internal` correctly.
- If adding a new volume, declare it in the top-level `volumes:` block.

### .env.example

- Keep `.env.example` in sync whenever you add a new required environment variable.
- Never put real values in `.env.example` — use `CHANGE_ME` or generator hints.
- Never read, print, or modify `.env` — it contains secrets.

### Adding a New MCP Server

This is done through the MetaMCP UI, not through config files. Document the server in README.md under "Adding new tools". The pattern is:

```json
{ "type": "STDIO", "command": "npx", "args": ["-y", "@modelcontextprotocol/server-NAME"] }
```

For servers without native MCP support, wrap them in a FastMCP STDIO server.

### Agent Config Examples (agents/)

- These are `.example` files — users copy and fill in real values locally.
- Never add real Bearer tokens or IPs to these files.
- Always use `/mcp` endpoint (Streamable HTTP), not `/sse`, unless documenting the SSE fallback path.

## Validation Checklist

Before declaring work complete, verify:

- [ ] `.env.example` has entries for all variables used in `docker-compose.yml`
- [ ] All `${VAR}` in `docker-compose.yml` have defaults (`:-default`) or are in `.env.example`
- [ ] `APP_URL` instructions clearly say "not localhost"
- [ ] Both agent examples point to `/mcp` not `/sse`
- [ ] `.gitignore` covers `.env`

## Out of Scope

- Do not provision the actual Debian host, install Docker, or configure Dockge — that is the user's responsibility.
- Do not generate real secrets — only provide `openssl rand -hex N` commands for the user to run.
- Obsidian vault integration is a planned next step, not part of this phase.
