\set ON_ERROR_STOP on

BEGIN;

SELECT set_config(
    'autoaudit.usuario_aplicacion',
    'daniel',
    true
);

SELECT set_config(
    'autoaudit.estacion',
    'VM Ubuntu BD1',
    true
);

SELECT set_config(
    'autoaudit.ip_origen',
    '10.0.2.15',
    true
);

UPDATE demo.producto
SET
    precio = precio + 10,
    existencia = existencia - 1,
    fecha_actualizacion = clock_timestamp()
WHERE nombre = 'Mouse inalambrico'
RETURNING
    id_producto,
    nombre,
    precio,
    existencia;

COMMIT;

SELECT
    bitacora.id_bitacora,
    tabla.nombre_esquema,
    tabla.nombre_tabla,
    bitacora.operacion,
    bitacora.clave_registro,
    bitacora.datos_anteriores ->> 'precio'
        AS precio_anterior,
    bitacora.datos_nuevos ->> 'precio'
        AS precio_nuevo,
    bitacora.datos_anteriores ->> 'existencia'
        AS existencia_anterior,
    bitacora.datos_nuevos ->> 'existencia'
        AS existencia_nueva,
    usuario.usuario_bd,
    usuario.usuario_aplicacion,
    estacion.direccion_ip,
    estacion.nombre_estacion
FROM auditoria.bitacora AS bitacora
JOIN auditoria.configuracion_auditoria AS configuracion
    ON configuracion.id_configuracion =
       bitacora.id_configuracion
JOIN auditoria.tabla_auditada AS tabla
    ON tabla.id_tabla = configuracion.id_tabla
JOIN auditoria.usuario_auditado AS usuario
    ON usuario.id_usuario = bitacora.id_usuario
LEFT JOIN auditoria.estacion_trabajo AS estacion
    ON estacion.id_estacion = bitacora.id_estacion
ORDER BY bitacora.id_bitacora DESC
LIMIT 1;

SELECT
    columna.nombre_columna,
    detalle.valor_anterior,
    detalle.valor_nuevo,
    detalle.cambio
FROM auditoria.bitacora_detalle AS detalle
JOIN auditoria.columna_auditada AS columna
    ON columna.id_columna = detalle.id_columna
WHERE detalle.id_bitacora = (
    SELECT max(id_bitacora)
    FROM auditoria.bitacora
)
ORDER BY columna.posicion;
