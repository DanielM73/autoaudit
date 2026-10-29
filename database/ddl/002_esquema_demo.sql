\set ON_ERROR_STOP on

BEGIN;

CREATE SCHEMA demo AUTHORIZATION autoaudit_owner;

REVOKE ALL ON SCHEMA demo FROM PUBLIC;
GRANT USAGE ON SCHEMA demo TO autoaudit_app;

CREATE TABLE demo.cliente (
    id_cliente bigint GENERATED ALWAYS AS IDENTITY,
    nombre varchar(150) NOT NULL,
    correo varchar(150) NOT NULL,
    telefono varchar(25),
    activo boolean NOT NULL DEFAULT true,
    fecha_registro timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT pk_cliente
        PRIMARY KEY (id_cliente),

    CONSTRAINT uq_cliente_correo
        UNIQUE (correo)
);

CREATE TABLE demo.producto (
    id_producto bigint GENERATED ALWAYS AS IDENTITY,
    nombre varchar(150) NOT NULL,
    precio numeric(12, 2) NOT NULL,
    existencia integer NOT NULL DEFAULT 0,
    activo boolean NOT NULL DEFAULT true,
    fecha_actualizacion timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT pk_producto
        PRIMARY KEY (id_producto),

    CONSTRAINT ck_producto_precio
        CHECK (precio > 0),

    CONSTRAINT ck_producto_existencia
        CHECK (existencia >= 0)
);

CREATE TABLE demo.venta (
    id_venta bigint GENERATED ALWAYS AS IDENTITY,
    id_cliente bigint NOT NULL,
    fecha_venta timestamptz NOT NULL DEFAULT clock_timestamp(),
    estado varchar(20) NOT NULL DEFAULT 'PENDIENTE',
    total numeric(14, 2) NOT NULL DEFAULT 0,

    CONSTRAINT pk_venta
        PRIMARY KEY (id_venta),

    CONSTRAINT fk_venta_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES demo.cliente (id_cliente)
        ON DELETE RESTRICT,

    CONSTRAINT ck_venta_estado
        CHECK (estado IN ('PENDIENTE', 'PAGADA', 'ANULADA')),

    CONSTRAINT ck_venta_total
        CHECK (total >= 0)
);

CREATE TABLE demo.detalle_venta (
    id_detalle bigint GENERATED ALWAYS AS IDENTITY,
    id_venta bigint NOT NULL,
    id_producto bigint NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(12, 2) NOT NULL,
    subtotal numeric(14, 2)
        GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,

    CONSTRAINT pk_detalle_venta
        PRIMARY KEY (id_detalle),

    CONSTRAINT fk_detalle_venta
        FOREIGN KEY (id_venta)
        REFERENCES demo.venta (id_venta)
        ON DELETE CASCADE,

    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (id_producto)
        REFERENCES demo.producto (id_producto)
        ON DELETE RESTRICT,

    CONSTRAINT ck_detalle_cantidad
        CHECK (cantidad > 0),

    CONSTRAINT ck_detalle_precio
        CHECK (precio_unitario > 0),

    CONSTRAINT uq_detalle_producto
        UNIQUE (id_venta, id_producto)
);

CREATE INDEX idx_venta_cliente
    ON demo.venta (id_cliente);

CREATE INDEX idx_detalle_venta
    ON demo.detalle_venta (id_venta);

CREATE INDEX idx_detalle_producto
    ON demo.detalle_venta (id_producto);

REVOKE ALL ON ALL TABLES IN SCHEMA demo FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA demo FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON ALL TABLES IN SCHEMA demo
    TO autoaudit_app;

GRANT USAGE, SELECT
    ON ALL SEQUENCES IN SCHEMA demo
    TO autoaudit_app;

COMMIT;
