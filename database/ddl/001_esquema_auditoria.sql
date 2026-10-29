\set ON_ERROR_STOP on

BEGIN;

CREATE SCHEMA auditoria AUTHORIZATION autoaudit_owner;

REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;
GRANT USAGE ON SCHEMA auditoria TO autoaudit_app;

CREATE TABLE auditoria.tabla_auditada (
    id_tabla bigint GENERATED ALWAYS AS IDENTITY,
    nombre_esquema varchar(63) NOT NULL,
    nombre_tabla varchar(63) NOT NULL,
    oid_tabla oid NOT NULL,
    activa boolean NOT NULL DEFAULT true,
    fecha_registro timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT pk_tabla_auditada
        PRIMARY KEY (id_tabla),

    CONSTRAINT uq_tabla_auditada_nombre
        UNIQUE (nombre_esquema, nombre_tabla)
);

CREATE TABLE auditoria.columna_auditada (
    id_columna bigint GENERATED ALWAYS AS IDENTITY,
    id_tabla bigint NOT NULL,
    nombre_columna varchar(63) NOT NULL,
    tipo_dato text NOT NULL,
    posicion integer NOT NULL,
    activa boolean NOT NULL DEFAULT true,

    CONSTRAINT pk_columna_auditada
        PRIMARY KEY (id_columna),

    CONSTRAINT fk_columna_tabla
        FOREIGN KEY (id_tabla)
        REFERENCES auditoria.tabla_auditada (id_tabla)
        ON DELETE RESTRICT,

    CONSTRAINT uq_columna_auditada_nombre
        UNIQUE (id_tabla, nombre_columna),

    CONSTRAINT ck_columna_posicion
        CHECK (posicion > 0)
);

CREATE TABLE auditoria.tipo_evento (
    id_evento smallint GENERATED ALWAYS AS IDENTITY,
    codigo varchar(10) NOT NULL,
    descripcion varchar(100) NOT NULL,

    CONSTRAINT pk_tipo_evento
        PRIMARY KEY (id_evento),

    CONSTRAINT uq_tipo_evento_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_tipo_evento_codigo
        CHECK (codigo IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE TABLE auditoria.configuracion_auditoria (
    id_configuracion bigint GENERATED ALWAYS AS IDENTITY,
    id_tabla bigint NOT NULL,
    id_evento smallint NOT NULL,
    version integer NOT NULL DEFAULT 1,
    activa boolean NOT NULL DEFAULT true,
    creada_por varchar(63) NOT NULL DEFAULT session_user,
    fecha_creacion timestamptz NOT NULL DEFAULT clock_timestamp(),
    fecha_desactivacion timestamptz,

    CONSTRAINT pk_configuracion_auditoria
        PRIMARY KEY (id_configuracion),

    CONSTRAINT fk_configuracion_tabla
        FOREIGN KEY (id_tabla)
        REFERENCES auditoria.tabla_auditada (id_tabla)
        ON DELETE RESTRICT,

    CONSTRAINT fk_configuracion_evento
        FOREIGN KEY (id_evento)
        REFERENCES auditoria.tipo_evento (id_evento)
        ON DELETE RESTRICT,

    CONSTRAINT uq_configuracion_version
        UNIQUE (id_tabla, id_evento, version),

    CONSTRAINT ck_configuracion_version
        CHECK (version > 0),

    CONSTRAINT ck_configuracion_estado
        CHECK (
            (activa AND fecha_desactivacion IS NULL)
            OR
            (NOT activa AND fecha_desactivacion IS NOT NULL)
        )
);

CREATE UNIQUE INDEX uq_configuracion_activa
    ON auditoria.configuracion_auditoria (id_tabla, id_evento)
    WHERE activa;

CREATE TABLE auditoria.configuracion_columna (
    id_configuracion bigint NOT NULL,
    id_columna bigint NOT NULL,

    CONSTRAINT pk_configuracion_columna
        PRIMARY KEY (id_configuracion, id_columna),

    CONSTRAINT fk_configuracion_columna_configuracion
        FOREIGN KEY (id_configuracion)
        REFERENCES auditoria.configuracion_auditoria (id_configuracion)
        ON DELETE RESTRICT,

    CONSTRAINT fk_configuracion_columna_columna
        FOREIGN KEY (id_columna)
        REFERENCES auditoria.columna_auditada (id_columna)
        ON DELETE RESTRICT
);

CREATE TABLE auditoria.usuario_auditado (
    id_usuario bigint GENERATED ALWAYS AS IDENTITY,
    usuario_bd varchar(63) NOT NULL,
    usuario_aplicacion varchar(100),
    nombre_mostrar varchar(150),
    activo boolean NOT NULL DEFAULT true,
    fecha_registro timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT pk_usuario_auditado
        PRIMARY KEY (id_usuario),

    CONSTRAINT uq_usuario_auditado_origen
        UNIQUE NULLS NOT DISTINCT (usuario_bd, usuario_aplicacion)
);

CREATE TABLE auditoria.estacion_trabajo (
    id_estacion bigint GENERATED ALWAYS AS IDENTITY,
    direccion_ip inet,
    nombre_estacion varchar(150),
    nombre_aplicacion varchar(150),
    primera_conexion timestamptz NOT NULL DEFAULT clock_timestamp(),
    ultima_conexion timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT pk_estacion_trabajo
        PRIMARY KEY (id_estacion),

    CONSTRAINT uq_estacion_trabajo_origen
        UNIQUE NULLS NOT DISTINCT (
            direccion_ip,
            nombre_estacion,
            nombre_aplicacion
        )
);

CREATE TABLE auditoria.bitacora (
    id_bitacora bigint GENERATED ALWAYS AS IDENTITY,
    id_configuracion bigint NOT NULL,
    id_usuario bigint NOT NULL,
    id_estacion bigint,
    operacion varchar(10) NOT NULL,
    fecha_evento timestamptz NOT NULL DEFAULT clock_timestamp(),
    id_transaccion bigint NOT NULL,
    clave_registro jsonb NOT NULL DEFAULT '{}'::jsonb,
    datos_anteriores jsonb,
    datos_nuevos jsonb,

    CONSTRAINT pk_bitacora
        PRIMARY KEY (id_bitacora),

    CONSTRAINT fk_bitacora_configuracion
        FOREIGN KEY (id_configuracion)
        REFERENCES auditoria.configuracion_auditoria (id_configuracion)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bitacora_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES auditoria.usuario_auditado (id_usuario)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bitacora_estacion
        FOREIGN KEY (id_estacion)
        REFERENCES auditoria.estacion_trabajo (id_estacion)
        ON DELETE RESTRICT,

    CONSTRAINT ck_bitacora_operacion
        CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),

    CONSTRAINT ck_bitacora_clave
        CHECK (jsonb_typeof(clave_registro) = 'object'),

    CONSTRAINT ck_bitacora_datos_operacion
        CHECK (
            (
                operacion = 'INSERT'
                AND datos_anteriores IS NULL
                AND datos_nuevos IS NOT NULL
            )
            OR
            (
                operacion = 'UPDATE'
                AND datos_anteriores IS NOT NULL
                AND datos_nuevos IS NOT NULL
            )
            OR
            (
                operacion = 'DELETE'
                AND datos_anteriores IS NOT NULL
                AND datos_nuevos IS NULL
            )
        )
);

CREATE TABLE auditoria.bitacora_detalle (
    id_detalle bigint GENERATED ALWAYS AS IDENTITY,
    id_bitacora bigint NOT NULL,
    id_columna bigint NOT NULL,
    valor_anterior jsonb,
    valor_nuevo jsonb,
    cambio boolean NOT NULL,

    CONSTRAINT pk_bitacora_detalle
        PRIMARY KEY (id_detalle),

    CONSTRAINT fk_detalle_bitacora
        FOREIGN KEY (id_bitacora)
        REFERENCES auditoria.bitacora (id_bitacora)
        ON DELETE CASCADE,

    CONSTRAINT fk_detalle_columna
        FOREIGN KEY (id_columna)
        REFERENCES auditoria.columna_auditada (id_columna)
        ON DELETE RESTRICT,

    CONSTRAINT uq_detalle_columna
        UNIQUE (id_bitacora, id_columna)
);

CREATE TABLE auditoria.trigger_generado (
    id_trigger bigint GENERATED ALWAYS AS IDENTITY,
    id_tabla bigint NOT NULL,
    nombre_trigger varchar(63) NOT NULL,
    nombre_funcion varchar(63) NOT NULL,
    codigo_generado text NOT NULL,
    activo boolean NOT NULL DEFAULT true,
    fecha_generacion timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT pk_trigger_generado
        PRIMARY KEY (id_trigger),

    CONSTRAINT fk_trigger_tabla
        FOREIGN KEY (id_tabla)
        REFERENCES auditoria.tabla_auditada (id_tabla)
        ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_trigger_generado_activo
    ON auditoria.trigger_generado (id_tabla)
    WHERE activo;

CREATE INDEX idx_columna_auditada_tabla
    ON auditoria.columna_auditada (id_tabla, activa);

CREATE INDEX idx_configuracion_tabla_evento
    ON auditoria.configuracion_auditoria (id_tabla, id_evento);

CREATE INDEX idx_bitacora_fecha
    ON auditoria.bitacora (fecha_evento DESC);

CREATE INDEX idx_bitacora_usuario_fecha
    ON auditoria.bitacora (id_usuario, fecha_evento DESC);

CREATE INDEX idx_bitacora_configuracion
    ON auditoria.bitacora (id_configuracion);

CREATE INDEX idx_bitacora_operacion
    ON auditoria.bitacora (operacion);

CREATE INDEX idx_bitacora_clave
    ON auditoria.bitacora USING gin (clave_registro);

CREATE INDEX idx_detalle_columna
    ON auditoria.bitacora_detalle (id_columna, id_bitacora);

INSERT INTO auditoria.tipo_evento (codigo, descripcion)
VALUES
    ('INSERT', 'Registro de datos nuevos'),
    ('UPDATE', 'Modificacion de datos existentes'),
    ('DELETE', 'Eliminacion de datos existentes');

REVOKE ALL ON ALL TABLES IN SCHEMA auditoria FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA auditoria FROM PUBLIC;

GRANT SELECT ON ALL TABLES IN SCHEMA auditoria TO autoaudit_app;

ALTER DEFAULT PRIVILEGES
    FOR ROLE autoaudit_owner
    IN SCHEMA auditoria
    REVOKE ALL ON TABLES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
    FOR ROLE autoaudit_owner
    IN SCHEMA auditoria
    GRANT SELECT ON TABLES TO autoaudit_app;

ALTER DEFAULT PRIVILEGES
    FOR ROLE autoaudit_owner
    IN SCHEMA auditoria
    REVOKE ALL ON SEQUENCES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
    FOR ROLE autoaudit_owner
    IN SCHEMA auditoria
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

COMMIT;
