#!/usr/bin/env bash
# =============================================================================
# bun.sh - Setup completo del entorno de desarrollo en WSL
# Instala: unzip, bun, dependencias del proyecto
# Uso: bash bun.sh
# =============================================================================

set -e  # Detener si algo falla

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
err()  { echo -e "  ${C_RED}✖${C_RESET}  $1"; exit 1; }
step() { echo -e "\n  ${C_WHITE}» $1${C_RESET}"; }
info() { echo -e "  ${C_GRAY}   $1${C_RESET}"; }

# ── Header ────────────────────────────────────────────────────────────────────
clear
echo ""
echo -e "  ${C_CYAN}╔══════════════════════════════════════════╗${C_RESET}"
echo -e "  ${C_CYAN}║     🛠️   Notion Worker - Setup WSL       ║${C_RESET}"
echo -e "  ${C_CYAN}║          bun.sh  |  Ubuntu               ║${C_RESET}"
echo -e "  ${C_CYAN}╚══════════════════════════════════════════╝${C_RESET}"
echo ""

PROJECT_DIR="$HOME/notion-demo"

# ── PASO 1: unzip ─────────────────────────────────────────────────────────────
step "Paso 1/4 — Verificando unzip..."

if command -v unzip &>/dev/null; then
    ok "unzip ya está instalado ($(unzip -v | head -1 | awk '{print $2}'))"
else
    warn "unzip no encontrado, instalando..."
    sudo apt-get update -qq
    sudo apt-get install unzip -y -qq
    ok "unzip instalado"
fi

# ── PASO 2: bun ───────────────────────────────────────────────────────────────
step "Paso 2/4 — Verificando bun..."

if command -v bun &>/dev/null; then
    ok "bun ya está instalado ($(bun --version))"
else
    warn "bun no encontrado, instalando..."
    curl -fsSL https://bun.sh/install | bash
    # Cargar bun en el PATH de esta sesión
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    ok "bun instalado ($(bun --version))"
fi

# Asegurar que bun esté en el PATH de esta sesión
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── PASO 3: Proyecto ──────────────────────────────────────────────────────────
step "Paso 3/4 — Verificando proyecto en $PROJECT_DIR..."

if [ ! -d "$PROJECT_DIR" ]; then
    err "No existe $PROJECT_DIR — crea el proyecto primero con: ntn workers create"
fi

cd "$PROJECT_DIR"
ok "Directorio encontrado: $PROJECT_DIR"

# Verificar package.json
if [ ! -f "package.json" ]; then
    err "No hay package.json en $PROJECT_DIR"
fi
ok "package.json encontrado"

# ── PASO 4: bun install ───────────────────────────────────────────────────────
step "Paso 4/4 — Instalando dependencias con bun..."
echo ""

# Limpiar node_modules con permisos si hay problemas previos
if [ -d "node_modules" ]; then
    info "Limpiando node_modules anterior..."
    rm -rf node_modules
fi

bun install

echo ""
ok "Dependencias instaladas"

# ── Resumen final ─────────────────────────────────────────────────────────────
echo ""
echo -e "  ${C_CYAN}╔══════════════════════════════════════════╗${C_RESET}"
echo -e "  ${C_CYAN}║        ✅  Setup completado!             ║${C_RESET}"
echo -e "  ${C_CYAN}╚══════════════════════════════════════════╝${C_RESET}"
echo ""
echo -e "  ${C_WHITE}Herramientas disponibles:${C_RESET}"
info "bun     → $(which bun) ($(bun --version))"
info "unzip   → $(which unzip)"
info "ntn     → $(which ntn 2>/dev/null || echo 'no encontrado — instala con: npm i -g ntn')"
echo ""
echo -e "  ${C_WHITE}Próximos pasos:${C_RESET}"
info "cd ~/notion-demo"
info "ntn workers deploy"
echo ""