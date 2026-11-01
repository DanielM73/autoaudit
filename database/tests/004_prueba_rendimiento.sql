\set ON_ERROR_STOP on
\pset pager off
\timing on

\echo
\echo 'PRUEBA DE RENDIMIENTO DE AUTOAUDIT'
\echo 'Se realizarán 250 actualizaciones dentro de una transacción.'
\echo 'Al finalizar se ejecutará ROLLBACK para no alterar los datos.'
\echo

BEGIN;

SELECT set_config(
    'autoaudit.usuario_aplicacion',
    'prueba_rendimiento',
    true
);

SELECT set_config(
    'autoaudit.nombre_estacion',
    'VM Ubuntu BD1',
    true
);

SELECT set_config(
    'autoaudit.direccion_ip',
    '10.0.2.15',
    true
);

SELECT count(*) AS registros_antes
FROM auditoria.bitacora
\gset

DO $$
DECLARE
    numero_actualizacion integer;
    cantidad_pruebas integer := 250;
    momento_inicial timestamptz;
    momento_final timestamptz;
    tiempo_total_ms numeric;
    promedio_ms numeric;
BEGIN
    momento_inicial := clock_timestamp();

    FOR numero_actualizacion IN 1..cantidad_pruebas LOOP
        UPDATE demo.producto
        SET
            precio = precio + 0.01,
            existencia = existencia + 1
        WHERE id_producto = 2;
    END LOOP;

    momento_final := clock_timestamp();

    tiempo_total_ms := round(
        (
            extract(
                epoch FROM momento_final - momento_inicial
            ) * 1000
        )::numeric,
        2
    );

    promedio_ms := round(
        tiempo_total_ms / cantidad_pruebas,
        4
    );

    RAISE NOTICE
        'Actualizaciones realizadas: %',
        cantidad_pruebas;

    RAISE NOTICE
        'Tiempo total: % milisegundos',
        tiempo_total_ms;

    RAISE NOTICE
        'Tiempo promedio por actualización: % milisegundos',
        promedio_ms;
END;
$$;

SELECT
    count(*) - :registros_antes AS registros_auditoria_generados
FROM auditoria.bitacora;

SELECT
    count(*) AS detalles_generados
FROM auditoria.bitacora_detalle AS detalle
WHERE detalle.id_bitacora IN (
    SELECT bitacora.id_bitacora
    FROM auditoria.bitacora AS bitacora
    WHERE bitacora.id_usuario IN (
        SELECT usuario.id_usuario
        FROM auditoria.usuario_auditado AS usuario
        WHERE usuario.usuario_aplicacion = 'prueba_rendimiento'
    )
);

SELECT
    id_producto,
    nombre,
    precio,
    existencia
FROM demo.producto
WHERE id_producto = 2;

ROLLBACK;

SELECT
    count(*) = :registros_antes AS rollback_correcto
FROM auditoria.bitacora;

\echo
\echo 'La prueba terminó. Los cambios y registros fueron revertidos.'
\echo

\timing off
