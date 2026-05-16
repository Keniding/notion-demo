# =============================================================================
# dev.ps1 - Notion Worker - Flujo de desarrollo completo
# Uso: .\dev.ps1 [comando]
#
# Comandos:
#   .\dev.ps1          -> Menu interactivo
#   .\dev.ps1 deploy   -> Deploy directo
#   .\dev.ps1 logs     -> Ver logs del ultimo run
#   .\dev.ps1 ls       -> Listar workers
#   .\dev.ps1 open     -> Abrir VS Code en WSL
#   .\dev.ps1 status   -> Ver estado del worker activo
# =============================================================================

param(
    [string]$Command = ""
)

# ── Helpers de color ──────────────────────────────────────────────────────────
function Title  { param($m) Write-Host "`n$m" -ForegroundColor Cyan }
function Ok     { param($m) Write-Host "  ✔  $m" -ForegroundColor Green }
function Warn   { param($m) Write-Host "  ⚠  $m" -ForegroundColor Yellow }
function Err    { param($m) Write-Host "  ✖  $m" -ForegroundColor Red }
function Info   { param($m) Write-Host "     $m" -ForegroundColor Gray }
function Step   { param($m) Write-Host "`n  » $m" -ForegroundColor White }

# ── Constantes ────────────────────────────────────────────────────────────────
$WSL_PROJECT = "~/notion-demo"
$WSL_DISTRO  = "Ubuntu"

# ── Función: ejecutar en WSL ──────────────────────────────────────────────────
function Invoke-WSL {
    param([string]$Cmd, [switch]$Interactive)
    if ($Interactive) {
        wsl -d $WSL_DISTRO -- bash -lc "cd $WSL_PROJECT && $Cmd"
    } else {
        $out = wsl -d $WSL_DISTRO -- bash -lc "cd $WSL_PROJECT && $Cmd" 2>&1
        return $out
    }
}

# ── Función: Header ───────────────────────────────────────────────────────────
function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║     🚀  Notion Worker Dev Console        ║" -ForegroundColor Cyan
    Write-Host "  ║        notion-demo  |  WSL Ubuntu        ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# ── Función: Status rápido ────────────────────────────────────────────────────
function Show-Status {
    Step "Estado del worker activo..."

    $workers = Invoke-WSL "ntn workers ls 2>/dev/null"
    $lines = ($workers | Out-String).Trim() -split "`n"

    # Filtrar solo filas con IDs (UUID)
    $workerLines = $lines | Where-Object { $_ -match "[0-9a-f]{8}-[0-9a-f]{4}" }

    if ($workerLines.Count -eq 0) {
        Warn "No hay workers deployados."
        return
    }

    foreach ($line in $workerLines) {
        $parts = $line.Trim() -split "\s{2,}"
        if ($parts.Count -ge 3) {
            $id      = $parts[0].Trim()
            $name    = $parts[1].Trim()
            $updated = if ($parts.Count -ge 4) { $parts[3].Trim() } else { $parts[2].Trim() }
            # Formatear fecha
            try {
                $dt = [datetime]::Parse($updated).ToLocalTime().ToString("dd/MM/yyyy HH:mm")
            } catch { $dt = $updated }
            Ok "$name"
            Info "ID      : $id"
            Info "Updated : $dt"
        }
    }
}

# ── Función: Deploy ───────────────────────────────────────────────────────────
function Invoke-Deploy {
    Step "Deployando worker..."
    Write-Host ""
    wsl -d $WSL_DISTRO -- bash -lc "cd $WSL_PROJECT && ntn workers deploy"
    Write-Host ""

    if ($LASTEXITCODE -eq 0) {
        Ok "Deploy exitoso!"
    } else {
        Err "Deploy falló. Revisa los logs arriba."
    }
}

# ── Función: Logs ─────────────────────────────────────────────────────────────
function Show-Logs {
    Step "Obteniendo runs recientes..."
    Write-Host ""

    $runs = Invoke-WSL "ntn workers runs list 2>/dev/null"
    $lines = ($runs | Out-String).Trim() -split "`n"
    $runLines = $lines | Where-Object { $_ -match "[0-9a-f]{8}-[0-9a-f]{4}" }

    if ($runLines.Count -eq 0) {
        Warn "No hay runs registrados."
        return
    }

    # Mostrar tabla de runs
    Write-Host "  Runs recientes:" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $i = 1
    $runIds = @()
    foreach ($line in $runLines | Select-Object -First 8) {
        $parts = $line.Trim() -split "\s{2,}"
        if ($parts.Count -ge 3) {
            $runId    = $parts[0].Trim()
            $runName  = $parts[1].Trim()
            $exitCode = $parts[2].Trim()
            $started  = if ($parts.Count -ge 4) { $parts[3].Trim() } else { "" }
            try {
                $dt = [datetime]::Parse($started).ToLocalTime().ToString("HH:mm:ss")
            } catch { $dt = $started }
            $status = if ($exitCode -eq "0") { "✔" } else { "✖" }
            $color  = if ($exitCode -eq "0") { "Green" } else { "Red" }
            Write-Host ("  [{0}] {1} {2,-28} {3}" -f $i, $status, $runName, $dt) -ForegroundColor $color
            $runIds += $runId
            $i++
        }
    }
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    # Preguntar si quiere ver logs de alguno
    $choice = Read-Host "  Ver logs de run numero (Enter para saltar)"
    if ($choice -match "^\d+$") {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $runIds.Count) {
            $selectedId = $runIds[$idx]
            Write-Host ""
            Step "Logs del run: $selectedId"
            Write-Host ""
            wsl -d $WSL_DISTRO -- bash -lc "ntn workers runs logs $selectedId"
        } else {
            Warn "Numero invalido."
        }
    }
}

# ── Función: Abrir VS Code ────────────────────────────────────────────────────
function Open-VSCode {
    Step "Abriendo VS Code en WSL..."
    wsl -d $WSL_DISTRO -- bash -lc "cd $WSL_PROJECT && code . &"
    Ok "VS Code abierto apuntando a $WSL_PROJECT"
}

# ── Función: Listar workers ───────────────────────────────────────────────────
function Show-Workers {
    Step "Workers en tu workspace..."
    Write-Host ""
    wsl -d $WSL_DISTRO -- bash -lc "ntn workers ls"
    Write-Host ""
}

# ── Función: Menu principal ───────────────────────────────────────────────────
function Show-Menu {
    Show-Header
    Show-Status

    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │           ¿Qué deseas hacer?        │" -ForegroundColor White
    Write-Host "  ├─────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │  [1]  🚀  Deploy worker             │" -ForegroundColor White
    Write-Host "  │  [2]  📋  Ver logs de runs          │" -ForegroundColor White
    Write-Host "  │  [3]  📦  Listar workers            │" -ForegroundColor White
    Write-Host "  │  [4]  💻  Abrir VS Code             │" -ForegroundColor White
    Write-Host "  │  [5]  🔄  Actualizar status         │" -ForegroundColor White
    Write-Host "  │  [q]  ❌  Salir                     │" -ForegroundColor White
    Write-Host "  └─────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""

    $choice = Read-Host "  Opcion"

    switch ($choice.ToLower()) {
        "1" { Invoke-Deploy;  Pause-Continue }
        "2" { Show-Logs;      Pause-Continue }
        "3" { Show-Workers;   Pause-Continue }
        "4" { Open-VSCode;    Pause-Continue }
        "5" { Show-Menu; return }
        "q" { Write-Host "`n  Hasta luego! 👋`n" -ForegroundColor Cyan; exit 0 }
        default { Warn "Opcion invalida."; Start-Sleep 1; Show-Menu }
    }

    Show-Menu
}

function Pause-Continue {
    Write-Host ""
    Read-Host "  Presiona Enter para volver al menu"
}

# ── Entry point ───────────────────────────────────────────────────────────────
switch ($Command.ToLower()) {
    "deploy" { Show-Header; Invoke-Deploy }
    "logs"   { Show-Header; Show-Logs }
    "ls"     { Show-Header; Show-Workers }
    "open"   { Show-Header; Open-VSCode }
    "status" { Show-Header; Show-Status; Write-Host "" }
    default  { Show-Menu }
}