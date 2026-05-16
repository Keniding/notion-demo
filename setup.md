# 🧠 Notion Worker — Dev Setup

> Worker serverless hospedado por Notion, desarrollado en TypeScript con el CLI `ntn`.

---

## 📋 Requisitos previos

| Herramienta | Versión mínima | Notas |
|-------------|---------------|-------|
| Windows 10/11 | — | Con WSL2 habilitado |
| WSL2 + Ubuntu | 22.04+ | Instalado vía `wsl --install -d Ubuntu` |
| Node.js | 18+ | Dentro de Ubuntu WSL |
| Bun | 1.x | Opcional, para Windows |
| `ntn` CLI | 0.14.0+ | CLI oficial de Notion |

---

## ⚡ Setup rápido

### Opción A — Script automático (recomendado)

**En PowerShell (Windows):**
```powershell
.\setup.ps1
```

---

### Opción B — Manual paso a paso

#### 1. Instalar Ubuntu en WSL (PowerShell como Admin)
```powershell
wsl --install -d Ubuntu
# Reinicia si es necesario
# Usuario: user / Password: el que elijas
```

#### 2. Entrar a Ubuntu WSL
```powershell
wsl -d Ubuntu
```

#### 3. Instalar `ntn` CLI
```bash
curl -fsSL "https://ntn.dev" | NTN_INSTALL_DIR="$HOME/.local/bin" bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
ntn --version  # ntn 0.14.0
```

#### 4. Autenticarse con Notion
```bash
# Opción A: Login interactivo (abre URL en el browser)
ntn login

# Opción B: Token de API directo
export NOTION_API_TOKEN=secret_xxxxxxxxxxxx
echo 'export NOTION_API_TOKEN=secret_xxxxxxxxxxxx' >> ~/.bashrc
```

#### 5. Crear o clonar el worker
```bash
# Nuevo worker desde template
ntn workers new my-worker
cd my-worker

# O clonar este repo
git clone <repo-url>
cd <repo>
npm install
```

#### 6. Deployar
```bash
ntn workers deploy
```

---

## 🗂️ Estructura del proyecto

```
notion-worker/
├── src/
│   └── index.ts        # Entry point del worker
├── package.json
├── tsconfig.json
├── setup.sh            # Script de setup para Ubuntu WSL
├── setup.ps1           # Script de setup para PowerShell/Windows
└── README.md
```

---

## 🔧 Comandos útiles

```bash
ntn --help                   # Ver todos los comandos
ntn workers new              # Crear nuevo worker
ntn workers deploy           # Deployar worker
ntn workers ls               # Listar workers desplegados
ntn workers exec <cap>       # Ejecutar una capability
ntn workers sync status      # Ver estado de syncs
ntn api ls                   # Listar endpoints de la API
ntn pages create             # Crear página desde Markdown
ntn files create < file.png  # Subir archivo
ntn login                    # Autenticarse
ntn logout                   # Cerrar sesión
```

---

## 📦 Tipos de capabilities

### 🔧 Tool — Función callable por un agente Notion
```typescript
worker.tool("myTool", {
  title: "My Tool",
  description: "Does something useful",
  schema: j.object({ input: j.string().describe("Input value") }),
  execute: ({ input }) => `Result: ${input}`,
});
```

### 🔄 Sync — Sincronizar datos externos a Notion
```typescript
worker.sync("mySync", {
  database: myDb,
  schedule: "15m",
  execute: async () => ({
    changes: [...],
    hasMore: false,
  }),
});
```

### 🌐 Webhook — Recibir eventos HTTP externos
```typescript
worker.webhook("onEvent", {
  title: "Event Handler",
  description: "Handles incoming events",
  execute: async (events) => {
    for (const event of events) console.log(event);
  },
});
```

---

## ⚠️ Notas importantes

- `ntn` **solo funciona en Linux/macOS**. En Windows usar **Ubuntu WSL**.
- El WSL de **Docker Desktop** NO es compatible (no tiene `bash`, `curl`, ni `apt`).
- Usar siempre `wsl -d Ubuntu` para abrir el entorno correcto.
- El token de Notion expira — renovar con `ntn login` si hay errores 401.

---

## 🔗 Referencias

- [Notion Workers Docs](https://github.com/makenotion/workers-template)
- [ntn CLI Reference](https://github.com/makenotion/skills/blob/main/skills/notion-cli/SKILL.md)
- [Notion API](https://developers.notion.com)
