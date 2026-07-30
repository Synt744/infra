#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Точка входа для восстановления системы с нуля
#
# Использование:
#   curl -fsSL https://<your-git-host>/raw/main/scripts/bootstrap.sh | bash
#   # или после клонирования:
#   bash scripts/bootstrap.sh
#
# Что делает:
#   1. Устанавливает минимальные зависимости (git, ansible)
#   2. Клонирует репозиторий (если запущен не из него)
#   3. Запрашивает профиль (workstation / laptop / server / raspberry)
#   4. Запускает основной playbook
# =============================================================================
set -euo pipefail

# ─── Константы ────────────────────────────────────────────────────────────────
REPO_URL="${INFRA_REPO_URL:-}"          # передай через env или впиши ниже
REPO_DIR="${HOME}/infra"
PROFILES_DIR="profiles"
DEFAULT_PROFILE="workstation"
LOG_FILE="/tmp/bootstrap-$(date +%Y%m%d-%H%M%S).log"

# ─── Цвета ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

# ─── Проверка дистрибутива ────────────────────────────────────────────────────
check_debian() {
  if ! grep -qi 'debian\|ubuntu' /etc/os-release 2>/dev/null; then
    error "Этот скрипт рассчитан на Debian/Ubuntu."
  fi
  info "Дистрибутив: $(. /etc/os-release && echo "$PRETTY_NAME")"
}

# ─── Установка зависимостей ───────────────────────────────────────────────────
install_deps() {
  info "Обновляю apt и устанавливаю зависимости..."
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends \
    git curl ca-certificates gnupg lsb-release \
    python3 python3-pip pipx 2>&1 | tee -a "$LOG_FILE"

  info "Устанавливаю Ansible через pipx..."
  pipx install --include-deps ansible 2>&1 | tee -a "$LOG_FILE" || true
  pipx ensurepath
  # Добавляем pipx bin в PATH для текущей сессии
  export PATH="${HOME}/.local/bin:${PATH}"
  ansible --version | head -1 | tee -a "$LOG_FILE"
}

# ─── Клонирование репо ────────────────────────────────────────────────────────
clone_repo() {
  if [[ -f "$(dirname "$0")/../ansible/playbooks/workstation.yml" ]]; then
    # Уже запущен изнутри репозитория
    REPO_DIR="$(realpath "$(dirname "$0")/..")"
    info "Репозиторий уже доступен: ${REPO_DIR}"
    return 0
  fi

  if [[ -z "$REPO_URL" ]]; then
    echo -n "Введи URL репозитория (git clone URL): "
    read -r REPO_URL
  fi

  if [[ -d "$REPO_DIR/.git" ]]; then
    info "Репозиторий уже клонирован, обновляю..."
    git -C "$REPO_DIR" pull --ff-only
  else
    info "Клонирую репозиторий в ${REPO_DIR}..."
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

# ─── Выбор профиля ───────────────────────────────────────────────────────────
select_profile() {
  local available
  available=$(find "${REPO_DIR}/${PROFILES_DIR}" -name "*.yml" -exec basename {} .yml \; 2>/dev/null | sort | tr '\n' ' ')

  echo ""
  echo "Доступные профили: ${available:-workstation laptop server raspberry}"
  echo -n "Профиль [${DEFAULT_PROFILE}]: "
  read -r PROFILE
  PROFILE="${PROFILE:-$DEFAULT_PROFILE}"

  local profile_file="${REPO_DIR}/${PROFILES_DIR}/${PROFILE}.yml"
  if [[ ! -f "$profile_file" ]]; then
    error "Профиль '${PROFILE}' не найден: ${profile_file}"
  fi
  info "Выбран профиль: ${PROFILE}"
}

# ─── Ansible Vault ────────────────────────────────────────────────────────────
prepare_vault() {
  local vault_file="${REPO_DIR}/ansible/group_vars/all/vault.yml"
  if [[ ! -f "$vault_file" ]]; then
    warn "Файл vault.yml не найден. Создай его по образцу vault.yml.example"
    warn "  cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml"
    warn "  # Заполни секреты, затем:"
    warn "  ansible-vault encrypt ansible/group_vars/all/vault.yml"
    echo -n "Продолжить без vault? (y/N): "
    read -r ans
    [[ "${ans,,}" == "y" ]] || error "Прерван. Сначала настрой vault.yml."
  fi
}

# ─── Запуск Ansible ───────────────────────────────────────────────────────────
run_ansible() {
  local profile_file="${REPO_DIR}/${PROFILES_DIR}/${PROFILE}.yml"
  cd "$REPO_DIR"

  local vault_args=""
  if [[ -f "ansible/group_vars/all/vault.yml" ]]; then
    vault_args="--ask-vault-pass"
  fi

  info "Запускаю playbook: ${PROFILE}..."
  ansible-playbook \
    -i ansible/inventories/local/hosts.yml \
    "${profile_file}" \
    ${vault_args} \
    --diff \
    "$@" \
    2>&1 | tee -a "$LOG_FILE"
}

# ─── Итог ─────────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  info "═══════════════════════════════════════════"
  info " Bootstrap завершён!"
  info " Лог: ${LOG_FILE}"
  info "═══════════════════════════════════════════"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  info "bootstrap.sh запущен. Лог: ${LOG_FILE}"
  check_debian
  install_deps
  clone_repo
  select_profile
  prepare_vault
  run_ansible "$@"
  print_summary
}

main "$@"
