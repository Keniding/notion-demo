#!/bin/bash
# =============================================================================
# setup-env.sh — Configura automáticamente el .env para notion-demo
# NOTA: El prefijo "NOTION_" está reservado por el SDK → se usa API_KEY
# =============================================================================

set -e

PROJECT_DIR="$HOME/notion-demo"
ENV_FILE="$PROJECT_DIR/.env"

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

echo ""
echo -e "  ${C_CYAN}╔══════════════════════════════════════════════╗${C_RESET}"
echo -e "  ${C_CYAN}║   🔧  Configuración de variables de entorno  ║${C_RESET}"
echo -e "  ${C_CYAN}╚══════════════════════════════════════════════╝${C_RESET}"
echo ""

# ── Mostrar .env actual si existe ────────────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    warn ".env ya existe con las siguientes variables:"
    echo ""
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        if [[ "$key" =~ (KEY|SECRET|TOKEN|PASSWORD) ]]; then
            echo -e "  ${C_WHITE}${key}${C_RESET} = ${C_GRAY}${value:0:10}...${C_RESET}"
        else
            echo -e "  ${C_WHITE}${key}${C_RESET} = ${C_CYAN}${value}${C_RESET}"
        fi
    done < "$ENV_FILE"
    echo ""
    read -p "  ¿Sobreescribir? (s/n): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[sS]$ ]]; then
        echo ""
        warn "Cancelado. .env no modificado."

        # Ofrecer solo hacer push
        read -p "  ¿Hacer push del .env actual al remoto? (s/n): " DO_PUSH
        if [[ "$DO_PUSH" =~ ^[sS]$ ]]; then
            cd "$PROJECT_DIR"
            ntn workers env push
            ok "Variables sincronizadas con el worker remoto"
        fi
        echo ""
        exit 0
    fi
fi

# ── 1. API KEY ────────────────────────────────────────────────────────────────
echo -e "  ${C_WHITE}📌 PASO 1: Notion API Key${C_RESET}"
echo -e "  ${C_GRAY}→ Ve a: https://www.notion.so/profile/integrations${C_RESET}"
echo -e "  ${C_GRAY}→ Abre tu integración → copia el 'Internal Integration Secret'${C_RESET}"
echo -e "  ${C_YELLOW}  ⚠  El prefijo 'NOTION_' está reservado → se guardará como API_KEY${C_RESET}"
echo ""
read -p "  Pega tu API Key (secret_xxx o ntn_xxx): " INPUT_KEY

if [[ -z "$INPUT_KEY" ]]; then
    err "API Key vacía. Abortando."
    exit 1
fi

# Validar formato
if [[ "$INPUT_KEY" =~ ^(secret_|ntn_) ]]; then
    ok "Formato de API Key válido"
else
    warn "Formato inusual. Asegúrate de que sea el token correcto."
fi

API_KEY="$INPUT_KEY"

# ── 2. DATABASE_ID ────────────────────────────────────────────────────────────
echo ""
echo -e "  ${C_WHITE}📌 PASO 2: Database ID${C_RESET}"
echo -e "  ${C_GRAY}→ Abre tu DB 'Proyectos' en Notion${C_RESET}"
echo -e "  ${C_GRAY}→ Copia la URL del navegador${C_RESET}"
echo -e "  ${C_GRAY}→ Ejemplo: https://www.notion.so/abc123...?v=...${C_RESET}"
echo ""
read -p "  Pega la URL completa de tu DB: " NOTION_URL

# Extraer el ID de la URL (32 caracteres hex)
DATABASE_ID=$(echo "$NOTION_URL" | grep -oE '[a-f0-9]{32}' | head -1)

if [ -z "$DATABASE_ID" ]; then
    echo ""
    warn "No se pudo extraer el ID de la URL."
    read -p "  Pega el DATABASE_ID manualmente (32 caracteres): " DATABASE_ID
fi

if [ -z "$DATABASE_ID" ]; then
    err "DATABASE_ID vacío. Abortando."
    exit 1
fi

ok "DATABASE_ID detectado: $DATABASE_ID"

# ── 3. Variables adicionales (opcional) ──────────────────────────────────────
echo ""
echo -e "  ${C_WHITE}📌 PASO 3: Variables adicionales (opcional)${C_RESET}"
echo -e "  ${C_GRAY}→ Agrega variables extra si tu worker las necesita${C_RESET}"
echo -e "  ${C_YELLOW}  ⚠  No uses el prefijo 'NOTION_' (está reservado)${C_RESET}"
echo ""

declare -A EXTRA_VARS
while true; do
    read -p "  Nombre de variable extra (Enter para terminar): " EXTRA_KEY
    [ -z "$EXTRA_KEY" ] && break

    # Validar prefijo reservado
    if [[ "$EXTRA_KEY" =~ ^NOTION_ ]]; then
        warn "El prefijo 'NOTION_' está reservado. Usa otro nombre."
        continue
    fi

    read -p "  Valor de ${EXTRA_KEY}: " EXTRA_VAL
    EXTRA_VARS["$EXTRA_KEY"]="$EXTRA_VAL"
    ok "Variable '${EXTRA_KEY}' agregada"
done

# ── 4. Escribir el .env ───────────────────────────────────────────────────────
echo ""
echo -e "  ${C_WHITE}📌 PASO 4: Guardando en $ENV_FILE ...${C_RESET}"

mkdir -p "$(dirname "$ENV_FILE")"

{
    echo "# Notion Worker — Variables de entorno"
    echo "# Generado: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# NOTA: El prefijo NOTION_ está reservado por el SDK"
    echo ""
    echo "API_KEY=${API_KEY}"
    echo "DATABASE_ID=${DATABASE_ID}"

    # Variables adicionales
    if [ ${#EXTRA_VARS[@]} -gt 0 ]; then
        echo ""
        echo "# Variables adicionales"
        for key in "${!EXTRA_VARS[@]}"; do
            echo "${key}=${EXTRA_VARS[$key]}"
        done
    fi
} > "$ENV_FILE"

ok ".env creado correctamente"

# ── 5. Resumen ────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${C_CYAN}╔══════════════════════════════════════════════╗${C_RESET}"
echo -e "  ${C_CYAN}║   ✅  Variables configuradas                 ║${C_RESET}"
echo -e "  ${C_CYAN}╚══════════════════════════════════════════════╝${C_RESET}"
echo ""
echo -e "  ${C_WHITE}API_KEY${C_RESET}      = ${C_GRAY}${API_KEY:0:10}... (oculto)${C_RESET}"
echo -e "  ${C_WHITE}DATABASE_ID${C_RESET}  = ${C_CYAN}${DATABASE_ID}${C_RESET}"
for key in "${!EXTRA_VARS[@]}"; do
    echo -e "  ${C_WHITE}${key}${C_RESET} = ${C_CYAN}${EXTRA_VARS[$key]}${C_RESET}"
done
echo ""

# ── 6. Push al remoto ─────────────────────────────────────────────────────────
cd "$PROJECT_DIR"
read -p "  ⬆️  ¿Hacer push de variables al worker remoto? (s/n): " DO_PUSH

if [[ "$DO_PUSH" =~ ^[sS]$ ]]; then
    echo ""
    ntn workers env push
    echo ""
    ok "Variables sincronizadas con el worker remoto"
fi

# ── 7. Deploy ─────────────────────────────────────────────────────────────────
echo ""
read -p "  🚀 ¿Hacer deploy ahora? (s/n): " DO_DEPLOY

if [[ "$DO_DEPLOY" =~ ^[sS]$ ]]; then
    echo ""
    echo -e "  ${C_WHITE}⏳ Ejecutando: ntn workers deploy ...${C_RESET}"
    ntn workers deploy
    echo ""
    ok "¡Deploy completado!"
else
    echo ""
    echo -e "  ${C_GRAY}👍 Listo. Cuando quieras deployar corre:${C_RESET}"
    echo -e "  ${C_CYAN}   cd ~/notion-demo && ./dev.sh deploy${C_RESET}"
fi

echo ""