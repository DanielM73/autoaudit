\set ON_ERROR_STOP on

BEGIN;

INSERT INTO demo.cliente (
    nombre,
    correo,
    telefono
)
VALUES
    ('Ana Lopez', 'ana.lopez@example.com', '5555-1001'),
    ('Carlos Mendez', 'carlos.mendez@example.com', '5555-1002'),
    ('Maria Garcia', 'maria.garcia@example.com', '5555-1003');

INSERT INTO demo.producto (
    nombre,
    precio,
    existencia
)
VALUES
    ('Teclado mecanico', 450.00, 20),
    ('Mouse inalambrico', 175.50, 35),
    ('Monitor 24 pulgadas', 1450.00, 10),
    ('Memoria USB 64 GB', 95.00, 50);

WITH nueva_venta AS (
    INSERT INTO demo.venta (
        id_cliente,
        estado
    )
    SELECT
        id_cliente,
        'PENDIENTE'
    FROM demo.cliente
    WHERE correo = 'ana.lopez@example.com'
    RETURNING id_venta
),
lineas (nombre_producto, cantidad) AS (
    VALUES
        ('Teclado mecanico', 1),
        ('Mouse inalambrico', 2)
)
INSERT INTO demo.detalle_venta (
    id_venta,
    id_producto,
    cantidad,
    precio_unitario
)
SELECT
    nueva_venta.id_venta,
    producto.id_producto,
    lineas.cantidad,
    producto.precio
FROM nueva_venta
CROSS JOIN lineas
JOIN demo.producto AS producto
    ON producto.nombre = lineas.nombre_producto;

WITH nueva_venta AS (
    INSERT INTO demo.venta (
        id_cliente,
        estado
    )
    SELECT
        id_cliente,
        'PAGADA'
    FROM demo.cliente
    WHERE correo = 'carlos.mendez@example.com'
    RETURNING id_venta
)
INSERT INTO demo.detalle_venta (
    id_venta,
    id_producto,
    cantidad,
    precio_unitario
)
SELECT
    nueva_venta.id_venta,
    producto.id_producto,
    1,
    producto.precio
FROM nueva_venta
JOIN demo.producto AS producto
    ON producto.nombre = 'Monitor 24 pulgadas';

UPDATE demo.venta AS venta
SET total = totales.total
FROM (
    SELECT
        id_venta,
        SUM(subtotal) AS total
    FROM demo.detalle_venta
    GROUP BY id_venta
) AS totales
WHERE totales.id_venta = venta.id_venta;

COMMIT;
