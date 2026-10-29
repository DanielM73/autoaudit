\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION auditoria.registrar_tabla(
    p_nombre_esquema text,
    p_nombre_tabla text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auditoria
AS $$
DECLARE
    v_oid_tabla oid;
    v_id_tabla bigint;
BEGIN
    IF p_nombre_esquema IS NULL
       OR btrim(p_nombre_esquema) = '' THEN
        RAISE EXCEPTION
            'El nombre del esquema es obligatorio';
    END IF;

    IF p_nombre_tabla IS NULL
       OR btrim(p_nombre_tabla) = '' THEN
        RAISE EXCEPTION
            'El nombre de la tabla es obligatorio';
    END IF;

    IF p_nombre_esquema = 'auditoria'
       OR p_nombre_esquema = 'information_schema'
       OR p_nombre_esquema ~ '^pg_' THEN
        RAISE EXCEPTION
            'El esquema % no puede ser auditado',
            p_nombre_esquema;
    END IF;

    SELECT clase.oid
    INTO v_oid_tabla
    FROM pg_class AS clase
    JOIN pg_namespace AS esquema
        ON esquema.oid = clase.relnamespace
    WHERE esquema.nspname = p_nombre_esquema
      AND clase.relname = p_nombre_tabla
      AND clase.relkind IN ('r', 'p');

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La tabla %.% no existe',
            p_nombre_esquema,
            p_nombre_tabla;
    END IF;

    INSERT INTO auditoria.tabla_auditada (
        nombre_esquema,
        nombre_tabla,
        oid_tabla,
        activa
    )
    VALUES (
        p_nombre_esquema,
        p_nombre_tabla,
        v_oid_tabla,
        true
    )
    ON CONFLICT (
        nombre_esquema,
        nombre_tabla
    )
    DO UPDATE
    SET
        oid_tabla = EXCLUDED.oid_tabla,
        activa = true
    RETURNING id_tabla
    INTO v_id_tabla;

    UPDATE auditoria.columna_auditada AS columna
    SET activa = false
    WHERE columna.id_tabla = v_id_tabla
      AND NOT EXISTS (
          SELECT 1
          FROM pg_attribute AS atributo
          WHERE atributo.attrelid = v_oid_tabla
            AND atributo.attnum > 0
            AND NOT atributo.attisdropped
            AND atributo.attname = columna.nombre_columna
      );

    INSERT INTO auditoria.columna_auditada (
        id_tabla,
        nombre_columna,
        tipo_dato,
        posicion,
        activa
    )
    SELECT
        v_id_tabla,
        atributo.attname,
        format_type(
            atributo.atttypid,
            atributo.atttypmod
        ),
        atributo.attnum,
        true
    FROM pg_attribute AS atributo
    WHERE atributo.attrelid = v_oid_tabla
      AND atributo.attnum > 0
      AND NOT atributo.attisdropped
    ON CONFLICT (
        id_tabla,
        nombre_columna
    )
    DO UPDATE
    SET
        tipo_dato = EXCLUDED.tipo_dato,
        posicion = EXCLUDED.posicion,
        activa = true;

    RETURN v_id_tabla;
END;
$$;

COMMENT ON FUNCTION auditoria.registrar_tabla(text, text) IS
    'Valida una tabla y registra sus columnas en AutoAudit';

REVOKE ALL
    ON FUNCTION auditoria.registrar_tabla(text, text)
    FROM PUBLIC;

GRANT EXECUTE
    ON FUNCTION auditoria.registrar_tabla(text, text)
    TO autoaudit_app;

COMMIT;
