#!/usr/bin/env bash
# =============================================================================
# dev.sh - Notion Worker - Flujo de desarrollo completo (WSL/Linux)
# Uso: ./dev.sh [comando]
#
# Comandos:
#   ./dev.sh           -> Menu interactivo
#   ./dev.sh deploy    -> Deploy directo
#   ./dev.sh logs      -> Ver logs del ultimo run
#   ./dev.sh ls        -> Listar workers
#   ./dev.sh open      -> Abrir VS Code
#   ./dev.sh status    -> Ver estado del worker activo
# =============================================================================

PROJECT_DIR="$HOME/notion-demo"
cd "$PROJECT_DIR" || { echo "Error: no existe $PROJECT_DIR"; exit 1; }

# ── Colores ───────────────────────────────────────────────────────────────────
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_WHITE='\033[1;37m'
C_GRAY='\033[0;90m'
C_RESET='\033[0m'

ok()   { echo -e "  ${C_GREEN}✔${C_RESET}  $1"; }
warn() { echo -e "  ${C_YELLOW}⚠${C_RESET}  $1"; }
err()  { echo -e "  ${C_RED}✖${C_RESET}  $1"; }
info() { echo -e "  ${C_GRAY}   $1${C_RESET}"; }
step() { echo -e "\n  ${C_WHITE}» $1${C_RESET}"; }

# ── Header ────────────────────────────────────────────────────────────────────
show_header() {
    clear
    echo ""
    echo -e "  ${C_CYAN}╔══════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_CYAN}║     🚀  Notion Worker Dev Console        ║${C_RESET}"
    echo -e "  ${C_CYAN}║        notion-demo  |  WSL Ubuntu        ║${C_RESET}"
    echo -e "  ${C_CYAN}╚══════════════════════════════════════════╝${C_RESET}"
    echo ""
}

# ── Status ────────────────────────────────────────────────────────────────────
show_status() {
    step "Estado del worker activo..."
    echo ""
    local workers
    workers=$(ntn workers ls 2>/dev/null)

    if echo "$workers" | grep -qE "[0-9a-f]{8}-[0-9a-f]{4}"; then
        echo "$workers" | grep -E "[0-9a-f]{8}-[0-9a-f]{4}" | while read -r line; do
            local id name updated
            id=$(echo "$line" | awk '{print $1}')
            name=$(echo "$line" | awk '{print $2}')
            updated=$(echo "$line" | awk '{print $4}')
            ok "$name"
            info "ID      : $id"
            info "Updated : $updated"
        done
    else
        warn "No hay workers deployados."
    fi
}

# ── Deploy ────────────────────────────────────────────────────────────────────
invoke_deploy() {
    step "Deployando worker..."
    echo ""
    ntn workers deploy
    echo ""
    if [ $? -eq 0 ]; then
        ok "Deploy exitoso!"
    else
        err "Deploy falló. Revisa los logs arriba."
    fi
}

# ── Logs ──────────────────────────────────────────────────────────────────────
show_logs() {
    step "Runs recientes..."
    echo ""

    local runs
    runs=$(ntn workers runs list 2>/dev/null)

    if ! echo "$runs" | grep -qE "[0-9a-f]{8}-[0-9a-f]{4}"; then
        warn "No hay runs registrados."
        return
    fi

    echo -e "  ${C_WHITE}Runs recientes:${C_RESET}"
    echo -e "  ${C_GRAY}─────────────────────────────────────────────────────${C_RESET}"

    local i=1
    declare -a run_ids=()

    while IFS= read -r line; do
        if echo "$line" | grep -qE "[0-9a-f]{8}-[0-9a-f]{4}"; then
            local run_id run_name exit_code started
            run_id=$(echo "$line"    | awk '{print $1}')
            run_name=$(echo "$line"  | awk '{print $2}')
            exit_code=$(echo "$line" | awk '{print $3}')
            started=$(echo "$line"   | awk '{print $4}' | cut -dT -f2 | cut -d. -f1)

            run_ids+=("$run_id")

            if [ "$exit_code" = "0" ]; then
                echo -e "  ${C_GREEN}[$i] ✔  ${run_name}  ${C_GRAY}${started}${C_RESET}"
            else
                echo -e "  ${C_RED}[$i] ✖  ${run_name}  ${C_GRAY}${started}${C_RESET}"
            fi
            ((i++))
        fi
    done <<< "$runs"

    echo -e "  ${C_GRAY}─────────────────────────────────────────────────────${C_RESET}"
    echo ""
    read -rp "  Ver logs de run numero (Enter para saltar): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local idx=$((choice - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#run_ids[@]}" ]; then
            local selected_id="${run_ids[$idx]}"
            echo ""
            step "Logs del run: $selected_id"
            echo ""
            ntn workers runs logs "$selected_id"
        else
            warn "Numero invalido."
        fi
    fi
}

# ── VS Code ───────────────────────────────────────────────────────────────────
open_vscode() {
    step "Abriendo VS Code..."
    code . &
    ok "VS Code abierto en $PROJECT_DIR"
}

# ── Listar workers ────────────────────────────────────────────────────────────
show_workers() {
    step "Workers en tu workspace..."
    echo ""
    ntn workers ls
    echo ""
}

# ── Pausa ─────────────────────────────────────────────────────────────────────
pause_continue() {
    echo ""
    read -rp "  Presiona Enter para volver al menu..."
}

# ── Menu ──────────────────────────────────────────────────────────────────────
show_menu() {
    show_header
    show_status

    echo ""
    echo -e "  ${C_GRAY}┌─────────────────────────────────────┐${C_RESET}"
    echo -e "  ${C_WHITE}│       ¿Qué deseas hacer?            │${C_RESET}"
    echo -e "  ${C_GRAY}├─────────────────────────────────────┤${C_RESET}"
    echo -e "  ${C_WHITE}│  [1]  🚀  Deploy worker             │${C_RESET}"
    echo -e "  ${C_WHITE}│  [2]  📋  Ver logs de runs          │${C_RESET}"
    echo -e "  ${C_WHITE}│  [3]  📦  Listar workers            │${C_RESET}"
    echo -e "  ${C_WHITE}│  [4]  💻  Abrir VS Code             │${C_RESET}"
    echo -e "  ${C_WHITE}│  [5]  🔄  Actualizar status         │${C_RESET}"
    echo -e "  ${C_WHITE}│  [q]  ❌  Salir                     │${C_RESET}"
    echo -e "  ${C_GRAY}└─────────────────────────────────────┘${C_RESET}"
    echo ""
    read -rp "  Opcion: " choice

    case "$choice" in
        1) invoke_deploy;  pause_continue; show_menu ;;
        2) show_logs;      pause_continue; show_menu ;;
        3) show_workers;   pause_continue; show_menu ;;
        4) open_vscode;    pause_continue; show_menu ;;
        5) show_menu ;;
        q|Q) echo -e "\n  ${C_CYAN}Hasta luego! 👋${C_RESET}\n"; exit 0 ;;
        *) warn "Opcion invalida."; sleep 1; show_menu ;;
    esac
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-}" in
    deploy) show_header; invoke_deploy ;;
    logs)   show_header; show_logs ;;
    ls)     show_header; show_workers ;;
    open)   show_header; open_vscode ;;
    status) show_header; show_status; echo "" ;;
    *)      show_menu ;;
esac