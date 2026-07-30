---
name: Infra IaC project
description: Ansible Infrastructure as Code для Debian рабочей станции — архитектура, правила, расположение файлов
---

## Расположение

Всё в `infra/`. Standalone MetaMCP Docker Compose дублируется в `mcp-hub/` (быстрый старт без Ansible).

## Архитектура

- Единственный источник переменных: `infra/ansible/group_vars/all/main.yml`
- Секреты: `vault.yml` (зашифрован, не коммитится), шаблон: `vault.yml.example`
- 19 ролей: common, packages, git, ssh, network, docker, dockge, metamcp, kde, fonts, flatpak, obsidian, ai, hermes, opencode, security, firewall, backup, updates
- 4 профиля: workstation (полный), laptop (backup on, metamcp off), server (без GUI), raspberry (минимум)
- Переключатели: `install_*: true/false` в профилях

## Ключевые правила

- `ansible.builtin.*` namespace обязателен
- notify + handlers вместо безусловных restart
- Шаблоны содержат `# Managed by Ansible` в первой строке
- Новый сервис = новая роль (не менять существующие)
- Docker сервисы: Ansible только создаёт dirs + templates + `docker compose up`

**Why:** Долговременная поддерживаемость, идемпотентность, полная воспроизводимость с нуля.
