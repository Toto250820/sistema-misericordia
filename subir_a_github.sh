#!/bin/bash
# ============================================================
# Sistema Misericordia — subir el proyecto a GitHub
# ============================================================
# Uso:
#   1. Descomprimí sistema-misericordia.zip en tu compu.
#   2. Abrí una terminal DENTRO de esa carpeta (sistema-misericordia/).
#   3. Reemplazá TU-USUARIO más abajo por tu usuario real de GitHub.
#   4. Corré:  bash subir_a_github.sh
# ============================================================

set -e  # si algo falla, corta acá y avisa, no sigue de largo

USUARIO_GITHUB="TU-USUARIO"   # <-- cambiá esto por tu usuario de GitHub
REPO="sistema-misericordia"

echo "Inicializando repo Git..."
git init
git add .
git commit -m "Primera version - Sistema Misericordia"
git branch -M main
git remote add origin "https://github.com/${USUARIO_GITHUB}/${REPO}.git"

echo "Subiendo a GitHub..."
git push -u origin main

echo ""
echo "Listo. Ahora andá a GitHub -> Settings -> Pages -> Deploy from a branch -> main / (root)."
echo "La app va a quedar en: https://${USUARIO_GITHUB}.github.io/${REPO}/app/"
