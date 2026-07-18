# ============================================================
# Sistema Misericordia - reestructurar carpeta y subir a GitHub
# ============================================================
# Que hace: mueve el contenido de app/ (index.html, css/, js/,
# manifest.json) un nivel arriba, a la raiz del proyecto, para que
# la URL de GitHub Pages funcione sin el /app/ al final.
# Conserva tu js/supabaseClient.js con las credenciales que ya
# habias cargado (no hace falta volver a escribirlas).
#
# Uso:
#   1. Copia este archivo DENTRO de tu carpeta sistema-misericordia
#      (la que ya tiene .git, app/, supabase/, etc.)
#   2. Abri PowerShell parado ahi y corre:
#        Unblock-File -Path .\reestructurar_y_subir.ps1
#        .\reestructurar_y_subir.ps1
# ============================================================

function Fail($msg) {
    Write-Host ""
    Write-Host "ERROR: $msg"
    exit 1
}

if (-not (Test-Path ".git")) {
    Fail "No encuentro una carpeta .git aca. Parate en la carpeta sistema-misericordia (la que ya usaste con subir_a_github_FINAL.ps1) y volve a correr esto."
}

if (-not (Test-Path "app\index.html")) {
    Write-Host "No encuentro app\index.html -- puede que ya lo hayas reestructurado antes. No hago nada mas."
    exit 0
}

Write-Host "Moviendo archivos de app/ a la raiz..."
Move-Item -Path "app\index.html" -Destination "index.html" -Force
Move-Item -Path "app\manifest.json" -Destination "manifest.json" -Force
if (Test-Path "css") { Remove-Item -Path "css" -Recurse -Force }
if (Test-Path "js")  { Remove-Item -Path "js" -Recurse -Force }
Move-Item -Path "app\css" -Destination "css" -Force
Move-Item -Path "app\js" -Destination "js" -Force
Remove-Item -Path "app" -Recurse -Force

Write-Host "OK: archivos movidos. Estructura actual:"
Get-ChildItem -Name

git add -A
if ($LASTEXITCODE -ne 0) { Fail "git add fallo." }

git commit -m "Reestructurar: mover app/ a la raiz para que funcione GitHub Pages"
if ($LASTEXITCODE -ne 0) {
    git status
    Fail "git commit fallo (mira el detalle arriba)."
}

Write-Host ""
Write-Host "Subiendo a GitHub..."
git push
if ($LASTEXITCODE -ne 0) {
    Fail "El push fallo. Pegale el error completo a Claude."
}

Write-Host ""
Write-Host "LISTO. Espera 1-2 minutos y refresca tu URL de GitHub Pages"
Write-Host "(la misma de siempre, SIN el /app/ al final ahora)."
