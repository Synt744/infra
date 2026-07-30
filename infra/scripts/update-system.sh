#!/usr/bin/env bash
# =============================================================================
# update-system.sh — Обновление инфраструктуры без потери данных
#
# Делает:
#   1. git pull (с проверкой конфликтов)
#   2. ansible-playbook --check (dry-run)
#   3. Применяет playbook (с подтверждением или флагом --yes)
#   4. docker compose pull + up -d для всех стеков
#
# Использование:
#   ./scripts/update-system.sh                  # интерактивный режим
#   ./scripts/update-system.sh --yes            # без подтверждений
#   ./scripts/update-system.sh --tags docker    # только docker-стеки
#   ./scripts/update-system.sh --check          # только dry-run
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(realpath "${SCRIPT_DIR}/..")"
LOG_FILE="/tmp/update-system-$(date +%Y%m%d-%H%M%S).log"
AUTO_YES=false
CHECK_ONLY=false
ANSIBLE_EXTRA_ARGS=()
PROFILE="${UPDATE_PROFILE:-workstation}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

# ─── Аргументы ───────────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y)       AUTO_YES=true ;;
      --check)        CHECK_ONLY=true ;;
      --tags)         ANSIBLE_EXTRA_ARGS+=("--tags" "$2"); shift ;;
      --profile)      PROFILE="$2"; shift ;;
      *)              ANSIBLE_EXTRA_ARGS+=("$1") ;;
    esac
    shift
  done
}

# ─── Git pull ─────────────────────────────────────────────────────────────────
git_pull() {
  info "Проверяю обновления репозитория..."
  cd "$REPO_DIR"

  local status
  status=$(git status --porcelain 2>&1)
  if [[ -n "$status" ]]; then
    warn "Есть незакоммиченные изменения:"
    git status --short
    if ! $AUTO_YES; then
      echo -n "Продолжить без git pull? (y/N): "
      read -r ans
      [[ "${ans,,}" == "y" ]] || error "Прерван."
    fi
    return 0
  fi

  git fetch origin
  local behind
  behind=$(git rev-list HEAD..origin/main --count 2>/dev/null || echo 0)
  if [[ "$behind" -gt 0 ]]; then
    info "Доступно ${behind} новых коммитов. Обновляю..."
    git pull --ff-only origin main
  else
    info "Репозиторий актуален."
  fi
}

# ─── Dry-run Ansible ─────────────────────────────────────────────────────────
ansible_check() {
  info "Запускаю ansible-playbook --check (dry-run)..."
  cd "$REPO_DIR"

  local vault_args=""
  [[ -f "ansible/group_vars/all/vault.yml" ]] && vault_args="--ask-vault-pass"

  ansible-playbook \
    -i ansible/inventories/local/hosts.yml \
    "profiles/${PROFILE}.yml" \
    --check --diff \
    ${vault_args} \
    "${ANSIBLE_EXTRA_ARGS[@]}" \
    2>&1 | tee -a "$LOG_FILE"
}

# ─── Применение Ansible ───────────────────────────────────────────────────────
ansible_apply() {
  if $CHECK_ONLY; then
    info "Режим --check: применение пропущено."
    return 0
  fi

  if ! $AUTO_YES; then
    echo -n "Применить изменения? (y/N): "
    read -r ans
    [[ "${ans,,}" == "y" ]] || { info "Прерван пользователем."; return 0; }
  fi

  info "Применяю playbook..."
  cd "$REPO_DIR"

  local vault_args=""
  [[ -f "ansible/group_vars/all/vault.yml" ]] && vault_args="--ask-vault-pass"

  ansible-playbook \
    -i ansible/inventories/local/hosts.yml \
    "profiles/${PROFILE}.yml" \
    --diff \
    ${vault_args} \
    "${ANSIBLE_EXTRA_ARGS[@]}" \
    2>&1 | tee -a "$LOG_FILE"
}

# ─── Обновление Docker стеков ────────────────────────────────────────────────
update_docker_stacks() {
  local stacks_dir="/opt/stacks"
  if [[ ! -d "$stacks_dir" ]]; then
    warn "Директория ${stacks_dir} не найдена, пропускаю Docker обновление."
    return 0
  fi

  info "Обновляю Docker стеки в ${stacks_dir}..."
  for stack_dir in "${stacks_dir}"/*/; do
    local compose_file="${stack_dir}docker-compose.yml"
    if [[ ! -f "$compose_file" ]]; then
      continue
    fi
    local stack_name
    stack_name=$(basename "$stack_dir")
    info "  Стек: ${stack_name}"
    docker compose -f "$compose_file" pull --quiet 2>&1 | tee -a "$LOG_FILE" || true
    docker compose -f "$compose_file" up -d --remove-orphans 2>&1 | tee -a "$LOG_FILE" || \
      warn "  Ошибка при обновлении стека ${stack_name}"
  done
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  info "update-system.sh запущен. Профиль: ${PROFILE}. Лог: ${LOG_FILE}"

  git_pull
  ansible_check
  ansible_apply

  if [[ "${ANSIBLE_EXTRA_ARGS[*]:-}" != *"--tags"* ]] || \
     [[ "${ANSIBLE_EXTRA_ARGS[*]:-}" == *"docker"* ]]; then
    update_docker_stacks
  fi

  info "═══════════════════════════════════════════"
  info " Обновление завершено. Лог: ${LOG_FILE}"
  info "═══════════════════════════════════════════"
}

main "$@"
