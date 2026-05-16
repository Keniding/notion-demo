# =============================================================================
# setup.ps1 - Notion Worker Dev Setup para Windows (PowerShell)
# Uso: powershell -ExecutionPolicy Bypass -File .\setup.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

function Write-Step  { param($msg) Write-Host "  >> $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "  OK $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  !! $msg" -ForegroundColor Yellow }
function Write-Title { param($msg) Write-Host $msg -ForegroundColor Cyan }

Write-Host ""
Write-Title "============================================"
Write-Title "   Notion Worker - Setup Windows/WSL"
Write-Title "============================================"
Write-Host ""

# 1. Verificar WSL instalado
Write-Step "Verificando WSL..."
try {
    $null = wsl --status 2>&1
    Write-Ok "WSL disponible."
} catch {
    Write-Warn "WSL no esta instalado. Ejecuta como Admin: wsl --install"
    exit 1
}

# 2. Verificar Ubuntu instalado
Write-Step "Verificando Ubuntu en WSL..."
$rawList = wsl --list 2>&1
$distroList = ($rawList | Out-String) -replace "`0", ""
$ubuntuFound = $distroList -match "Ubuntu"

if (-not $ubuntuFound) {
    Write-Warn "Ubuntu no encontrado en WSL. Instalando..."
    wsl --install -d Ubuntu
    Write-Ok "Ubuntu instalado. Reinicia PowerShell y vuelve a ejecutar este script."
    exit 0
}
Write-Ok "Ubuntu WSL encontrado."

# 3. Instalar ntn dentro de Ubuntu WSL
Write-Step "Verificando ntn CLI en Ubuntu WSL..."
$ntnCheck = wsl -d Ubuntu -- bash -lc "command -v ntn 2>/dev/null || echo ''"

if ($ntnCheck -and $ntnCheck.Trim() -ne "") {
    $ntnVer = wsl -d Ubuntu -- bash -lc "ntn --version 2>/dev/null"
    Write-Ok "ntn ya instalado: $($ntnVer.Trim())"
} else {
    Write-Warn "ntn no encontrado. Instalando..."
    wsl -d Ubuntu -- bash -lc "mkdir -p `$HOME/.local/bin && curl -fsSL 'https://ntn.dev' | NTN_INSTALL_DIR=`$HOME/.local/bin bash"
    wsl -d Ubuntu -- bash -lc "grep -q '.local/bin' ~/.bashrc || echo 'export PATH=`$HOME/.local/bin:`$PATH' >> ~/.bashrc"
    $ntnVer = wsl -d Ubuntu -- bash -lc "ntn --version 2>/dev/null"
    Write-Ok "ntn instalado: $($ntnVer.Trim())"
}

# 4. Verificar autenticacion Notion
Write-Host ""
Write-Step "Verificando autenticacion con Notion..."
$tokenCheck = wsl -d Ubuntu -- bash -lc "cat ~/.config/ntn/config.json 2>/dev/null | grep -c 'token' || echo 0"
if ($tokenCheck -and $tokenCheck.Trim() -ne "0") {
    Write-Ok "Sesion de Notion activa."
} else {
    Write-Warn "No hay sesion activa."
    $doLogin = Read-Host "  Deseas hacer ntn login ahora? (y/n)"
    if ($doLogin -eq "y" -or $doLogin -eq "Y") {
        wsl -d Ubuntu -- bash -lc "ntn login"
    }
}

# 5. Crear/verificar proyecto en filesystem NATIVO de Linux
Write-Host ""
Write-Step "Verificando proyecto en filesystem Linux (~`$HOME/notion-demo)..."
$projectExists = wsl -d Ubuntu -- bash -lc "test -f ~/notion-demo/package.json && echo 'yes' || echo 'no'"

if ($projectExists.Trim() -eq "yes") {
    Write-Ok "Proyecto ya existe en ~/notion-demo"
} else {
    Write-Warn "Proyecto no encontrado. Creando en ~/notion-demo..."
    Write-Host ""
    Write-Host "  IMPORTANTE: El proyecto se crea en el filesystem nativo de Linux" -ForegroundColor Yellow
    Write-Host "  para evitar corrupcion de archivos en NTFS (Windows)." -ForegroundColor Yellow
    Write-Host "  Usa 'code .' desde Ubuntu WSL para abrir con VS Code." -ForegroundColor Yellow
    Write-Host ""
    wsl -d Ubuntu -- bash -lc "mkdir -p ~/notion-demo && cd ~/notion-demo && ntn workers new"
}

# 6. Instalar dependencias si faltan
Write-Host ""
Write-Step "Verificando dependencias npm..."
$depsExist = wsl -d Ubuntu -- bash -lc "test -d ~/notion-demo/node_modules && echo 'yes' || echo 'no'"
if ($depsExist.Trim() -eq "yes") {
    Write-Ok "Dependencias ya instaladas."
} else {
    Write-Warn "Instalando dependencias..."
    wsl -d Ubuntu -- bash -lc "cd ~/notion-demo && npm install"
    Write-Ok "Dependencias instaladas."
}

# Done
Write-Host ""
Write-Title "============================================"
Write-Title "   Setup completado!"
Write-Title "============================================"
Write-Host ""
Write-Host "Para trabajar en el proyecto:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Abre Ubuntu WSL:" -ForegroundColor White
Write-Host "     wsl -d Ubuntu" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Ve al proyecto (filesystem Linux, sin bugs NTFS):" -ForegroundColor White
Write-Host "     cd ~/notion-demo" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Abre VS Code desde WSL:" -ForegroundColor White
Write-Host "     code ." -ForegroundColor Cyan
Write-Host ""
Write-Host "Comandos ntn:" -ForegroundColor White
Write-Host "  ntn workers deploy   -> Deployar worker" -ForegroundColor Cyan
Write-Host "  ntn workers ls       -> Listar workers" -ForegroundColor Cyan
Write-Host "  ntn --help           -> Ver todos los comandos" -ForegroundColor Cyan
Write-Host ""