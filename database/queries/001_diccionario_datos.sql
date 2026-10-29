\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW auditoria.v_tablas_disponibles AS
SELECT
    clase.oid AS oid_tabla,
    esquema.nspname AS nombre_esquema,
    clase.relname AS nombre_tabla,
    CASE clase.relkind
        WHEN 'r' THEN 'TABLA'
        WHEN 'p' THEN 'TABLA PARTICIONADA'
    END AS tipo_tabla,
    pg_get_userbyid(clase.relowner) AS propietario,
    clase.reltuples::bigint AS registros_estimados,
    pg_total_relation_size(clase.oid) AS tamano_bytes
FROM pg_class AS clase
JOIN pg_namespace AS esquema
    ON esquema.oid = clase.relnamespace
WHERE clase.relkind IN ('r', 'p')
  AND esquema.nspname NOT LIKE 'pg_%'
  AND esquema.nspname <> 'information_schema'
  AND esquema.nspname <> 'auditoria';

CREATE OR REPLACE VIEW auditoria.v_columnas_disponibles AS
SELECT
    clase.oid AS oid_tabla,
    esquema.nspname AS nombre_esquema,
    clase.relname AS nombre_tabla,
    atributo.attnum AS posicion,
    atributo.attname AS nombre_columna,
    format_type(
        atributo.atttypid,
        atributo.atttypmod
    ) AS tipo_dato,
    NOT atributo.attnotnull AS permite_nulos,
    pg_get_expr(
        valor_defecto.adbin,
        valor_defecto.adrelid
    ) AS valor_defecto,
    atributo.attidentity <> '' AS es_identidad,
    atributo.attgenerated <> '' AS es_generada
FROM pg_attribute AS atributo
JOIN pg_class AS clase
    ON clase.oid = atributo.attrelid
JOIN pg_namespace AS esquema
    ON esquema.oid = clase.relnamespace
LEFT JOIN pg_attrdef AS valor_defecto
    ON valor_defecto.adrelid = atributo.attrelid
   AND valor_defecto.adnum = atributo.attnum
WHERE clase.relkind IN ('r', 'p')
  AND atributo.attnum > 0
  AND NOT atributo.attisdropped
  AND esquema.nspname NOT LIKE 'pg_%'
  AND esquema.nspname <> 'information_schema'
  AND esquema.nspname <> 'auditoria';

CREATE OR REPLACE VIEW auditoria.v_claves_primarias AS
SELECT
    clase.oid AS oid_tabla,
    esquema.nspname AS nombre_esquema,
    clase.relname AS nombre_tabla,
    atributo.attname AS nombre_columna,
    posicion.ordinalidad AS posicion_clave
FROM pg_class AS clase
JOIN pg_namespace AS esquema
    ON esquema.oid = clase.relnamespace
JOIN pg_index AS indice
    ON indice.indrelid = clase.oid
   AND indice.indisprimary
CROSS JOIN LATERAL
    unnest(indice.indkey)
    WITH ORDINALITY AS posicion(numero_atributo, ordinalidad)
JOIN pg_attribute AS atributo
    ON atributo.attrelid = clase.oid
   AND atributo.attnum = posicion.numero_atributo
WHERE clase.relkind IN ('r', 'p')
  AND esquema.nspname NOT LIKE 'pg_%'
  AND esquema.nspname <> 'information_schema'
  AND esquema.nspname <> 'auditoria';

COMMENT ON VIEW auditoria.v_tablas_disponibles IS
    'Tablas que pueden ser seleccionadas para auditoria';

COMMENT ON VIEW auditoria.v_columnas_disponibles IS
    'Columnas disponibles en las tablas de usuario';

COMMENT ON VIEW auditoria.v_claves_primarias IS
    'Columnas que forman la llave primaria de cada tabla';

REVOKE ALL
    ON auditoria.v_tablas_disponibles
    FROM PUBLIC;

REVOKE ALL
    ON auditoria.v_columnas_disponibles
    FROM PUBLIC;

REVOKE ALL
    ON auditoria.v_claves_primarias
    FROM PUBLIC;

GRANT SELECT
    ON auditoria.v_tablas_disponibles
    TO autoaudit_app;

GRANT SELECT
    ON auditoria.v_columnas_disponibles
    TO autoaudit_app;

GRANT SELECT
    ON auditoria.v_claves_primarias
    TO autoaudit_app;

COMMIT;
