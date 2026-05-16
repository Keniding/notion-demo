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
#   ./dev.sh env       -> Gestionar variables de entorno
# =============================================================================

PROJECT_DIR="$HOME/notion-demo"
ENV_FILE="$PROJECT_DIR/.env"
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
            id=$(echo "$line"      | awk '{print $1}')
            name=$(echo "$line"    | awk '{print $2}')
            updated=$(echo "$line" | awk '{print $4}')
            ok "$name"
            info "ID      : $id"
            info "Updated : $updated"
        done
    else
        warn "No hay workers deployados."
    fi

    # Mostrar estado del .env
    echo ""
    if [ -f "$ENV_FILE" ]; then
        local var_count
        var_count=$(grep -c '=' "$ENV_FILE" 2>/dev/null || echo 0)
        ok ".env encontrado ($var_count variables)"
    else
        warn ".env no encontrado — corre opción [6] para configurar"
    fi
}

# ── Deploy ────────────────────────────────────────────────────────────────────
invoke_deploy() {
    step "Deployando worker..."
    echo ""

    # Push env vars antes de deploy si existe .env
    if [ -f "$ENV_FILE" ]; then
        step "Sincronizando variables de entorno..."
        ntn workers env push --yes 2>/dev/null && ok "Variables sincronizadas" || warn "No se pudieron sincronizar variables"
        echo ""
    fi

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

# ── Gestión de Environments ───────────────────────────────────────────────────
manage_env() {
    show_header
    echo -e "  ${C_GRAY}┌─────────────────────────────────────┐${C_RESET}"
    echo -e "  ${C_WHITE}│     🔧  Variables de Entorno         │${C_RESET}"
    echo -e "  ${C_GRAY}├─────────────────────────────────────┤${C_RESET}"
    echo -e "  ${C_WHITE}│  [1]  📋  Ver variables remotas      │${C_RESET}"
    echo -e "  ${C_WHITE}│  [2]  ⬆️   Push .env → remoto         │${C_RESET}"
    echo -e "  ${C_WHITE}│  [3]  ⬇️   Pull remoto → .env         │${C_RESET}"
    echo -e "  ${C_WHITE}│  [4]  ✏️   Editar .env local          │${C_RESET}"
    echo -e "  ${C_WHITE}│  [5]  ➕  Agregar variable            │${C_RESET}"
    echo -e "  ${C_WHITE}│  [6]  🗑️   Eliminar variable          │${C_RESET}"
    echo -e "  ${C_WHITE}│  [7]  🔧  Setup inicial (.env)        │${C_RESET}"
    echo -e "  ${C_WHITE}│  [b]  ◀   Volver al menu              │${C_RESET}"
    echo -e "  ${C_GRAY}└─────────────────────────────────────┘${C_RESET}"
    echo ""
    read -rp "  Opcion: " env_choice

    case "$env_choice" in
        1) env_list ;;
        2) env_push ;;
        3) env_pull ;;
        4) env_edit ;;
        5) env_add ;;
        6) env_delete ;;
        7) bash "$PROJECT_DIR/setup-env.sh"; pause_continue ;;
        b|B) return ;;
        *) warn "Opcion invalida."; sleep 1 ;;
    esac

    [[ "$env_choice" != "b" && "$env_choice" != "B" ]] && { pause_continue; manage_env; }
}

env_list() {
    step "Variables en el worker remoto..."
    echo ""
    ntn workers env list
    echo ""
    if [ -f "$ENV_FILE" ]; then
        echo ""
        step "Variables en .env local:"
        echo -e "  ${C_GRAY}─────────────────────────────────────────${C_RESET}"
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            # Ocultar valores sensibles
            if [[ "$key" =~ (KEY|SECRET|TOKEN|PASSWORD|PASS) ]]; then
                echo -e "  ${C_WHITE}${key}${C_RESET} = ${C_GRAY}${value:0:8}...${C_RESET}"
            else
                echo -e "  ${C_WHITE}${key}${C_RESET} = ${C_CYAN}${value}${C_RESET}"
            fi
        done < "$ENV_FILE"
        echo -e "  ${C_GRAY}─────────────────────────────────────────${C_RESET}"
    else
        warn ".env local no encontrado"
    fi
}

env_push() {
    step "Subiendo variables al worker remoto..."
    echo ""
    if [ ! -f "$ENV_FILE" ]; then
        err ".env no encontrado en $ENV_FILE"
        warn "Corre la opción [7] para configurar las variables primero"
        return
    fi
    ntn workers env push
    echo ""
    ok "Variables sincronizadas con el worker remoto"
}

env_pull() {
    step "Descargando variables del worker remoto..."
    echo ""
    if [ -f "$ENV_FILE" ]; then
        warn "Esto sobreescribirá tu .env local"
        read -rp "  ¿Continuar? (s/n): " confirm
        [[ ! "$confirm" =~ ^[sS]$ ]] && { warn "Cancelado."; return; }
    fi
    ntn workers env pull
    echo ""
    ok "Variables descargadas a .env local"
}

env_edit() {
    step "Abriendo .env en editor..."
    echo ""
    if [ ! -f "$ENV_FILE" ]; then
        warn ".env no existe. Creando archivo vacío..."
        touch "$ENV_FILE"
    fi
    # Intentar abrir con nano, luego vi
    if command -v nano &>/dev/null; then
        nano "$ENV_FILE"
    else
        vi "$ENV_FILE"
    fi
    echo ""
    ok ".env guardado"
    read -rp "  ¿Hacer push de los cambios al remoto? (s/n): " do_push
    [[ "$do_push" =~ ^[sS]$ ]] && env_push
}

env_add() {
    step "Agregar nueva variable de entorno..."
    echo ""
    read -rp "  Nombre de la variable (ej: DATABASE_ID): " var_name

    if [ -z "$var_name" ]; then
        warn "Nombre vacío. Cancelado."
        return
    fi

    # Validar que no use prefijos reservados
    if [[ "$var_name" =~ ^NOTION_ ]]; then
        err "El prefijo 'NOTION_' está reservado por el SDK"
        warn "Usa un nombre diferente (ej: API_KEY en vez de NOTION_API_KEY)"
        return
    fi

    read -rp "  Valor: " var_value

    # Agregar al .env local
    echo "${var_name}=${var_value}" >> "$ENV_FILE"
    ok "Variable agregada al .env local: ${var_name}"

    read -rp "  ¿Hacer push al remoto ahora? (s/n): " do_push
    if [[ "$do_push" =~ ^[sS]$ ]]; then
        ntn workers env set "${var_name}=${var_value}" && ok "Variable subida al remoto"
    fi
}

env_delete() {
    step "Eliminar variable de entorno..."
    echo ""
    if [ ! -f "$ENV_FILE" ]; then
        warn ".env no encontrado"
        return
    fi

    echo -e "  ${C_WHITE}Variables disponibles:${C_RESET}"
    local i=1
    declare -a var_names=()
    while IFS='=' read -r key _; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        echo -e "  ${C_GRAY}[$i]${C_RESET} $key"
        var_names+=("$key")
        ((i++))
    done < "$ENV_FILE"

    echo ""
    read -rp "  Número de variable a eliminar (Enter para cancelar): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local idx=$((choice - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#var_names[@]}" ]; then
            local del_key="${var_names[$idx]}"
            # Eliminar del .env local
            sed -i "/^${del_key}=/d" "$ENV_FILE"
            ok "Variable '${del_key}' eliminada del .env local"
            read -rp "  ¿Eliminar también del remoto? (s/n): " do_remote
            [[ "$do_remote" =~ ^[sS]$ ]] && ntn workers env unset "$del_key" && ok "Eliminada del remoto"
        else
            warn "Número inválido."
        fi
    fi
}

# ── Pausa ─────────────────────────────────────────────────────────────────────
pause_continue() {
    echo ""
    read -rp "  Presiona Enter para volver al menu..."
}

# ── Menu principal ────────────────────────────────────────────────────────────
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
    echo -e "  ${C_WHITE}│  [6]  🔧  Gestionar variables .env  │${C_RESET}"
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
        6) manage_env;     show_menu ;;
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
    env)    show_header; manage_env ;;
    *)      show_menu ;;
esac