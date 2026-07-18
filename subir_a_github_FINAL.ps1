# ============================================================
# Sistema Misericordia - subir el proyecto a GitHub
# VERSION FINAL - usar solo este archivo, borrar los anteriores
# (subir_a_github.sh, subir_a_github.ps1, subir_a_github_v2.ps1)
# ============================================================
# Uso:
#   1. Pone este archivo DENTRO de la carpeta sistema-misericordia,
#      al mismo nivel que app/ y supabase/.
#   2. Abri PowerShell parado en esa carpeta y corre:
#        Unblock-File -Path .\subir_a_github_FINAL.ps1
#        .\subir_a_github_FINAL.ps1
#   3. Te va a ir preguntando lo que haga falta.
# ============================================================

function Fail($msg) {
    Write-Host ""
    Write-Host "ERROR: $msg"
    exit 1
}

# --- 1. Verificar Git instalado ---
git --version *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "No se encontro Git. Instalalo desde https://git-scm.com/download/win, cerra y volve a abrir PowerShell, y volve a correr este script."
}
Write-Host "OK: Git encontrado."

# --- 2. Verificar / configurar identidad de Git (nombre y email) ---
$nombre = git config --global user.name
if ([string]::IsNullOrWhiteSpace($nombre)) {
    Write-Host ""
    Write-Host "Git necesita saber quien sos para poder commitear (una sola vez)."
    $nombre = Read-Host "Tu nombre (ej: Javier Spinelli)"
    $email  = Read-Host "Tu email (puede ser cualquiera, ej: el de GitHub)"
    git config --global user.name "$nombre"
    git config --global user.email "$email"
    Write-Host "OK: Identidad de Git configurada."
}
else {
    Write-Host "OK: Identidad de Git ya configurada ($nombre)."
}

# --- 3. Pedir usuario de GitHub y nombre del repo ---
Write-Host ""
$UsuarioGitHub = Read-Host "Tu usuario de GitHub (tal cual aparece en github.com/TU-USUARIO)"
if ([string]::IsNullOrWhiteSpace($UsuarioGitHub)) { Fail "No ingresaste un usuario. Volve a correr el script." }
$Repo = "sistema-misericordia"

# --- 4. Inicializar repo si hace falta ---
if (-not (Test-Path ".git")) {
    git init
    if ($LASTEXITCODE -ne 0) { Fail "git init fallo." }
}

git add .
if ($LASTEXITCODE -ne 0) { Fail "git add fallo." }

# --- 5. Commit (si no hay nada nuevo, no es un error) ---
git commit -m "Primera version - Sistema Misericordia"
if ($LASTEXITCODE -ne 0) {
    git status
    Fail "git commit fallo (mira el detalle arriba). Si dice 'nothing to commit' esta OK, segui con el push a mano."
}

git branch -M main
if ($LASTEXITCODE -ne 0) { Fail "git branch -M main fallo." }

# --- 6. Configurar el remoto (si ya existe, lo actualiza) ---
git remote remove origin *> $null
git remote add origin "https://github.com/$UsuarioGitHub/$Repo.git"
if ($LASTEXITCODE -ne 0) { Fail "git remote add fallo." }

# --- 7. Confirmar que hay al menos un commit antes de pushear ---
git log --oneline -1 *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "No hay ningun commit todavia (git log no encontro nada). Revisa el paso 5 de arriba."
}

# --- 8. Push ---
Write-Host ""
Write-Host "Subiendo a GitHub... (puede pedirte iniciar sesion en una ventana del navegador)"
git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Fail "El push fallo. Motivos comunes: (a) el nombre del repo en GitHub no es exactamente '$Repo', (b) no confirmaste el login en la ventana del navegador, (c) el repo en GitHub no esta vacio. Pegale el error completo a Claude."
}

Write-Host ""
Write-Host "LISTO. Ahora anda a GitHub -> Settings -> Pages -> Deploy from a branch -> main / (root)."
Write-Host "La app va a quedar en: https://$UsuarioGitHub.github.io/$Repo/app/"
