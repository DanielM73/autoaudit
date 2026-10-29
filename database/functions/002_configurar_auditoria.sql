\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION auditoria.validar_configuracion_columna()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, auditoria
AS $$
DECLARE
    v_tabla_configuracion bigint;
    v_tabla_columna bigint;
BEGIN
    SELECT id_tabla
    INTO v_tabla_configuracion
    FROM auditoria.configuracion_auditoria
    WHERE id_configuracion = NEW.id_configuracion;

    SELECT id_tabla
    INTO v_tabla_columna
    FROM auditoria.columna_auditada
    WHERE id_columna = NEW.id_columna;

    IF v_tabla_configuracion IS DISTINCT FROM v_tabla_columna THEN
        RAISE EXCEPTION
            'La columna seleccionada no pertenece a la tabla configurada';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_configuracion_columna
BEFORE INSERT OR UPDATE
ON auditoria.configuracion_columna
FOR EACH ROW
EXECUTE FUNCTION auditoria.validar_configuracion_columna();

CREATE OR REPLACE FUNCTION auditoria.configurar_auditoria(
    p_nombre_esquema text,
    p_nombre_tabla text,
    p_codigo_evento text,
    p_columnas text[] DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auditoria
AS $$
DECLARE
    v_id_tabla bigint;
    v_id_evento smallint;
    v_id_configuracion bigint;
    v_version integer;
    v_columnas_faltantes text[];
    v_columnas_insertadas integer;
BEGIN
    v_id_tabla := auditoria.registrar_tabla(
        p_nombre_esquema,
        p_nombre_tabla
    );

    SELECT id_evento
    INTO v_id_evento
    FROM auditoria.tipo_evento
    WHERE codigo = upper(btrim(p_codigo_evento));

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El evento % no es valido. Utilice INSERT, UPDATE o DELETE',
            p_codigo_evento;
    END IF;

    IF p_columnas IS NOT NULL THEN
        IF cardinality(p_columnas) = 0 THEN
            RAISE EXCEPTION
                'Debe seleccionar al menos una columna';
        END IF;

        SELECT array_agg(
            solicitud.nombre_columna
            ORDER BY solicitud.nombre_columna
        )
        INTO v_columnas_faltantes
        FROM (
            SELECT DISTINCT
                btrim(valor.nombre_columna) AS nombre_columna
            FROM unnest(p_columnas)
                AS valor(nombre_columna)
        ) AS solicitud
        WHERE solicitud.nombre_columna IS NULL
           OR solicitud.nombre_columna = ''
           OR NOT EXISTS (
               SELECT 1
               FROM auditoria.columna_auditada AS columna
               WHERE columna.id_tabla = v_id_tabla
                 AND columna.nombre_columna =
                     solicitud.nombre_columna
                 AND columna.activa
           );

        IF v_columnas_faltantes IS NOT NULL THEN
            RAISE EXCEPTION
                'Las siguientes columnas no existen o no estan activas: %',
                v_columnas_faltantes;
        END IF;
    END IF;

    PERFORM 1
    FROM auditoria.tabla_auditada
    WHERE id_tabla = v_id_tabla
    FOR UPDATE;

    UPDATE auditoria.configuracion_auditoria
    SET
        activa = false,
        fecha_desactivacion = clock_timestamp()
    WHERE id_tabla = v_id_tabla
      AND id_evento = v_id_evento
      AND activa;

    SELECT COALESCE(MAX(version), 0) + 1
    INTO v_version
    FROM auditoria.configuracion_auditoria
    WHERE id_tabla = v_id_tabla
      AND id_evento = v_id_evento;

    INSERT INTO auditoria.configuracion_auditoria (
        id_tabla,
        id_evento,
        version,
        activa,
        creada_por
    )
    VALUES (
        v_id_tabla,
        v_id_evento,
        v_version,
        true,
        session_user
    )
    RETURNING id_configuracion
    INTO v_id_configuracion;

    INSERT INTO auditoria.configuracion_columna (
        id_configuracion,
        id_columna
    )
    SELECT DISTINCT
        v_id_configuracion,
        columna.id_columna
    FROM auditoria.columna_auditada AS columna
    WHERE columna.id_tabla = v_id_tabla
      AND columna.activa
      AND (
          p_columnas IS NULL
          OR columna.nombre_columna = ANY (p_columnas)
      );

    GET DIAGNOSTICS
        v_columnas_insertadas = ROW_COUNT;

    IF v_columnas_insertadas = 0 THEN
        RAISE EXCEPTION
            'No se seleccionaron columnas para la configuracion';
    END IF;

    RETURN v_id_configuracion;
END;
$$;

CREATE OR REPLACE FUNCTION auditoria.desactivar_auditoria(
    p_nombre_esquema text,
    p_nombre_tabla text,
    p_codigo_evento text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auditoria
AS $$
DECLARE
    v_actualizada boolean;
BEGIN
    UPDATE auditoria.configuracion_auditoria
    SET
        activa = false,
        fecha_desactivacion = clock_timestamp()
    WHERE id_configuracion IN (
        SELECT configuracion.id_configuracion
        FROM auditoria.configuracion_auditoria AS configuracion
        JOIN auditoria.tabla_auditada AS tabla
            ON tabla.id_tabla = configuracion.id_tabla
        JOIN auditoria.tipo_evento AS evento
            ON evento.id_evento = configuracion.id_evento
        WHERE tabla.nombre_esquema = p_nombre_esquema
          AND tabla.nombre_tabla = p_nombre_tabla
          AND evento.codigo = upper(btrim(p_codigo_evento))
          AND configuracion.activa
    );

    v_actualizada := FOUND;

    RETURN v_actualizada;
END;
$$;

CREATE OR REPLACE VIEW auditoria.v_configuracion_actual AS
SELECT
    configuracion.id_configuracion,
    tabla.nombre_esquema,
    tabla.nombre_tabla,
    evento.codigo AS evento,
    configuracion.version,
    configuracion.creada_por,
    configuracion.fecha_creacion,
    array_agg(
        columna.nombre_columna
        ORDER BY columna.posicion
    ) AS columnas
FROM auditoria.configuracion_auditoria AS configuracion
JOIN auditoria.tabla_auditada AS tabla
    ON tabla.id_tabla = configuracion.id_tabla
JOIN auditoria.tipo_evento AS evento
    ON evento.id_evento = configuracion.id_evento
JOIN auditoria.configuracion_columna AS seleccion
    ON seleccion.id_configuracion =
       configuracion.id_configuracion
JOIN auditoria.columna_auditada AS columna
    ON columna.id_columna = seleccion.id_columna
WHERE configuracion.activa
GROUP BY
    configuracion.id_configuracion,
    tabla.nombre_esquema,
    tabla.nombre_tabla,
    evento.codigo,
    configuracion.version,
    configuracion.creada_por,
    configuracion.fecha_creacion;

REVOKE ALL
    ON FUNCTION auditoria.validar_configuracion_columna()
    FROM PUBLIC;

REVOKE ALL
    ON FUNCTION auditoria.configurar_auditoria(
        text,
        text,
        text,
        text[]
    )
    FROM PUBLIC;

REVOKE ALL
    ON FUNCTION auditoria.desactivar_auditoria(
        text,
        text,
        text
    )
    FROM PUBLIC;

GRANT EXECUTE
    ON FUNCTION auditoria.configurar_auditoria(
        text,
        text,
        text,
        text[]
    )
    TO autoaudit_app;

GRANT EXECUTE
    ON FUNCTION auditoria.desactivar_auditoria(
        text,
        text,
        text
    )
    TO autoaudit_app;

REVOKE ALL
    ON auditoria.v_configuracion_actual
    FROM PUBLIC;

GRANT SELECT
    ON auditoria.v_configuracion_actual
    TO autoaudit_app;

COMMIT;
