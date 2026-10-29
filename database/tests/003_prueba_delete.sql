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

DELETE FROM demo.producto
WHERE nombre = 'Audifonos USB'
RETURNING
    id_producto,
    nombre,
    precio,
    existencia;

COMMIT;

SELECT
    bitacora.id_bitacora,
    bitacora.operacion,
    bitacora.clave_registro,
    bitacora.datos_anteriores ->> 'nombre'
        AS nombre_anterior,
    bitacora.datos_anteriores ->> 'precio'
        AS precio_anterior,
    bitacora.datos_anteriores ->> 'existencia'
        AS existencia_anterior,
    bitacora.datos_nuevos IS NULL
        AS sin_datos_nuevos,
    usuario.usuario_bd,
    usuario.usuario_aplicacion,
    estacion.direccion_ip
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
WHERE tabla.nombre_esquema = 'demo'
  AND tabla.nombre_tabla = 'producto'
  AND bitacora.operacion = 'DELETE'
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
    SELECT max(bitacora.id_bitacora)
    FROM auditoria.bitacora AS bitacora
    JOIN auditoria.configuracion_auditoria AS configuracion
        ON configuracion.id_configuracion =
           bitacora.id_configuracion
    JOIN auditoria.tabla_auditada AS tabla
        ON tabla.id_tabla = configuracion.id_tabla
    WHERE tabla.nombre_esquema = 'demo'
      AND tabla.nombre_tabla = 'producto'
      AND bitacora.operacion = 'DELETE'
)
ORDER BY columna.posicion;

SELECT
    NOT EXISTS (
        SELECT 1
        FROM demo.producto
        WHERE nombre = 'Audifonos USB'
    ) AS eliminado_de_tabla_original,
    EXISTS (
        SELECT 1
        FROM auditoria.bitacora
        WHERE operacion = 'DELETE'
          AND datos_anteriores ->> 'nombre' =
              'Audifonos USB'
    ) AS conservado_en_bitacora;
