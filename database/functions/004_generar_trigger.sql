\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION auditoria.generar_trigger(
    p_nombre_esquema text,
    p_nombre_tabla text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auditoria
AS $$
DECLARE
    v_id_tabla bigint;
    v_oid_tabla oid;
    v_nombre_trigger text;
    v_codigo_generado text;
    v_configuraciones_activas integer;
BEGIN
    v_id_tabla := auditoria.registrar_tabla(
        p_nombre_esquema,
        p_nombre_tabla
    );

    SELECT oid_tabla
    INTO v_oid_tabla
    FROM auditoria.tabla_auditada
    WHERE id_tabla = v_id_tabla;

    SELECT count(*)
    INTO v_configuraciones_activas
    FROM auditoria.configuracion_auditoria
    WHERE id_tabla = v_id_tabla
      AND activa;

    IF v_configuraciones_activas = 0 THEN
        RAISE EXCEPTION
            'La tabla %.% no tiene configuraciones activas',
            p_nombre_esquema,
            p_nombre_tabla;
    END IF;

    IF NOT has_table_privilege(
        current_user,
        v_oid_tabla,
        'TRIGGER'
    ) THEN
        RAISE EXCEPTION
            'AutoAudit no tiene permiso TRIGGER sobre %.%',
            p_nombre_esquema,
            p_nombre_tabla;
    END IF;

    v_nombre_trigger :=
        'trg_autoaudit_' || v_id_tabla::text;

    v_codigo_generado := format(
        'DROP TRIGGER IF EXISTS %I ON %I.%I;%s'
        'CREATE TRIGGER %I '
        'AFTER INSERT OR UPDATE OR DELETE '
        'ON %I.%I '
        'FOR EACH ROW '
        'EXECUTE FUNCTION auditoria.registrar_cambio();',
        v_nombre_trigger,
        p_nombre_esquema,
        p_nombre_tabla,
        E'\n',
        v_nombre_trigger,
        p_nombre_esquema,
        p_nombre_tabla
    );

    EXECUTE format(
        'DROP TRIGGER IF EXISTS %I ON %I.%I',
        v_nombre_trigger,
        p_nombre_esquema,
        p_nombre_tabla
    );

    EXECUTE format(
        'CREATE TRIGGER %I '
        'AFTER INSERT OR UPDATE OR DELETE '
        'ON %I.%I '
        'FOR EACH ROW '
        'EXECUTE FUNCTION auditoria.registrar_cambio()',
        v_nombre_trigger,
        p_nombre_esquema,
        p_nombre_tabla
    );

    UPDATE auditoria.trigger_generado
    SET activo = false
    WHERE id_tabla = v_id_tabla
      AND activo;

    INSERT INTO auditoria.trigger_generado (
        id_tabla,
        nombre_trigger,
        nombre_funcion,
        codigo_generado,
        activo
    )
    VALUES (
        v_id_tabla,
        v_nombre_trigger,
        'registrar_cambio',
        v_codigo_generado,
        true
    );

    RETURN v_nombre_trigger;
END;
$$;

CREATE OR REPLACE VIEW auditoria.v_triggers_activos AS
SELECT
    registro.id_trigger,
    tabla.nombre_esquema,
    tabla.nombre_tabla,
    registro.nombre_trigger,
    registro.nombre_funcion,
    registro.fecha_generacion,
    EXISTS (
        SELECT 1
        FROM pg_trigger AS trigger_bd
        WHERE trigger_bd.tgrelid = tabla.oid_tabla
          AND trigger_bd.tgname =
              registro.nombre_trigger
          AND NOT trigger_bd.tgisinternal
    ) AS instalado
FROM auditoria.trigger_generado AS registro
JOIN auditoria.tabla_auditada AS tabla
    ON tabla.id_tabla = registro.id_tabla
WHERE registro.activo;

COMMENT ON FUNCTION auditoria.generar_trigger(text, text) IS
    'Genera el trigger AFTER de una tabla configurada';

REVOKE ALL
    ON FUNCTION auditoria.generar_trigger(text, text)
    FROM PUBLIC;

GRANT EXECUTE
    ON FUNCTION auditoria.generar_trigger(text, text)
    TO autoaudit_app;

REVOKE ALL
    ON auditoria.v_triggers_activos
    FROM PUBLIC;

GRANT SELECT
    ON auditoria.v_triggers_activos
    TO autoaudit_app;

COMMIT;
