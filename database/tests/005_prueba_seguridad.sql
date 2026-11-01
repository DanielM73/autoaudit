\set ON_ERROR_STOP on
\pset pager off

\echo
\echo 'PRUEBA DE SEGURIDAD DE AUTOAUDIT'
\echo

BEGIN;

SELECT
    CASE
        WHEN has_database_privilege(
            current_user,
            current_database(),
            'CONNECT'
        )
        THEN 'OK'
        ELSE 'ERROR'
    END AS conexion_base_datos;

SELECT
    CASE
        WHEN has_schema_privilege(
            current_user,
            'auditoria',
            'USAGE'
        )
        THEN 'OK'
        ELSE 'ERROR'
    END AS uso_esquema_auditoria;

SELECT
    CASE
        WHEN NOT has_schema_privilege(
            current_user,
            'public',
            'CREATE'
        )
        THEN 'OK'
        ELSE 'ERROR'
    END AS creacion_objetos_restringida;

SELECT
    CASE
        WHEN has_table_privilege(
            current_user,
            'auditoria.bitacora',
            'SELECT'
        )
        THEN 'OK'
        ELSE 'ERROR'
    END AS consulta_bitacora;

SELECT
    CASE
        WHEN NOT has_table_privilege(
            current_user,
            'auditoria.bitacora',
            'INSERT'
        )
        AND NOT has_table_privilege(
            current_user,
            'auditoria.bitacora',
            'UPDATE'
        )
        AND NOT has_table_privilege(
            current_user,
            'auditoria.bitacora',
            'DELETE'
        )
        THEN 'OK'
        ELSE 'ERROR'
    END AS escritura_directa_restringida;

SELECT
    CASE
        WHEN NOT has_function_privilege(
            current_user,
            'auditoria.registrar_cambio()',
            'EXECUTE'
        )
        THEN 'OK'
        ELSE 'ERROR'
    END AS funcion_trigger_restringida;

DO $$
BEGIN
    BEGIN
        INSERT INTO auditoria.bitacora
        DEFAULT VALUES;

        RAISE EXCEPTION
            'ERROR: fue posible insertar directamente en la bitácora';

    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE
                'OK: INSERT directo en bitácora fue rechazado';
    END;

    BEGIN
        UPDATE auditoria.bitacora
        SET operacion = operacion
        WHERE id_bitacora = (
            SELECT min(id_bitacora)
            FROM auditoria.bitacora
        );

        RAISE EXCEPTION
            'ERROR: fue posible actualizar directamente la bitácora';

    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE
                'OK: UPDATE directo en bitácora fue rechazado';
    END;

    BEGIN
        DELETE FROM auditoria.bitacora
        WHERE false;

        RAISE EXCEPTION
            'ERROR: fue posible eliminar directamente la bitácora';

    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE
                'OK: DELETE directo en bitácora fue rechazado';
    END;

    BEGIN
        EXECUTE
            'CREATE TABLE public.prueba_permiso_autoaudit (
                id integer
            )';

        RAISE EXCEPTION
            'ERROR: fue posible crear una tabla en public';

    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE
                'OK: creación de tablas fue rechazada';
    END;

    BEGIN
        PERFORM auditoria.registrar_cambio();

        RAISE EXCEPTION
            'ERROR: fue posible ejecutar directamente el trigger';

    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE
                'OK: ejecución directa del trigger fue rechazada';
    END;
END;
$$;

ROLLBACK;

\echo
\echo 'La prueba de seguridad terminó correctamente.'
\echo
