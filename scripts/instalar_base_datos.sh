#!/usr/bin/env bash

set -euo pipefail

DIRECTORIO_PROYECTO="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-autoaudit_db}"
DB_OWNER="${DB_OWNER:-autoaudit_owner}"

ARCHIVOS_SQL=(
    "database/ddl/001_esquema_auditoria.sql"
    "database/ddl/002_esquema_demo.sql"
    "database/queries/001_diccionario_datos.sql"
    "database/functions/001_registrar_tabla.sql"
    "database/functions/002_configurar_auditoria.sql"
    "database/functions/003_registrar_cambio.sql"
    "database/functions/004_generar_trigger.sql"
    "database/seeds/001_datos_demo.sql"
)

echo
echo "Instalación de la base de datos de AutoAudit"
echo "Base de datos: ${DB_NAME}"
echo "Usuario propietario: ${DB_OWNER}"
echo

read -r -s -p "Contraseña de ${DB_OWNER}: " PGPASSWORD
echo

export PGPASSWORD

limpiar_contrasena() {
    unset PGPASSWORD
}

trap limpiar_contrasena EXIT

cd "${DIRECTORIO_PROYECTO}"

for archivo in "${ARCHIVOS_SQL[@]}"; do
    if [[ ! -f "${archivo}" ]]; then
        echo "No se encontró el archivo: ${archivo}"
        exit 1
    fi

    echo
    echo "Ejecutando ${archivo}..."

    psql \
        -X \
        -v ON_ERROR_STOP=1 \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_OWNER}" \
        -d "${DB_NAME}" \
        -f "${archivo}"
done

echo
echo "Verificando la instalación..."

psql \
    -X \
    -v ON_ERROR_STOP=1 \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_OWNER}" \
    -d "${DB_NAME}" \
    -c "
        SELECT
            table_schema,
            count(*) AS cantidad_tablas
        FROM information_schema.tables
        WHERE table_schema IN ('auditoria', 'demo')
          AND table_type = 'BASE TABLE'
        GROUP BY table_schema
        ORDER BY table_schema;
    "

echo
echo "La base de datos de AutoAudit fue instalada correctamente."
echo
