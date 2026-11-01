#!/usr/bin/env bash

set -euo pipefail

DIRECTORIO_PROYECTO="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)"

cd "${DIRECTORIO_PROYECTO}"

if [[ ! -d ".venv" ]]; then
    echo "No se encontró el entorno virtual .venv."
    echo "Créalo con: python3 -m venv .venv"
    exit 1
fi

if [[ ! -f ".env" ]]; then
    echo "No se encontró el archivo .env."
    echo "Créalo a partir de .env.example."
    exit 1
fi

source .venv/bin/activate

echo
echo "Iniciando AutoAudit..."
echo "Dirección local: http://127.0.0.1:5000"
echo "Para detener el servidor utiliza Ctrl + C."
echo

exec python run.py
