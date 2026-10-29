\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION auditoria.registrar_cambio()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auditoria
AS $$
DECLARE
    v_id_configuracion bigint;
    v_id_usuario bigint;
    v_id_estacion bigint;
    v_id_bitacora bigint;
    v_datos_anteriores jsonb;
    v_datos_nuevos jsonb;
    v_clave_registro jsonb;
    v_usuario_aplicacion text;
    v_nombre_estacion text;
    v_nombre_aplicacion text;
    v_direccion_ip_texto text;
    v_direccion_ip inet;
    v_debe_registrar boolean;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_datos_anteriores := NULL;
        v_datos_nuevos := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_datos_anteriores := to_jsonb(OLD);
        v_datos_nuevos := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        v_datos_anteriores := to_jsonb(OLD);
        v_datos_nuevos := NULL;
    ELSE
        RAISE EXCEPTION
            'Operacion no soportada por AutoAudit: %',
            TG_OP;
    END IF;

    SELECT configuracion.id_configuracion
    INTO v_id_configuracion
    FROM auditoria.configuracion_auditoria AS configuracion
    JOIN auditoria.tabla_auditada AS tabla
        ON tabla.id_tabla = configuracion.id_tabla
    JOIN auditoria.tipo_evento AS evento
        ON evento.id_evento = configuracion.id_evento
    WHERE tabla.nombre_esquema = TG_TABLE_SCHEMA
      AND tabla.nombre_tabla = TG_TABLE_NAME
      AND tabla.activa
      AND evento.codigo = TG_OP
      AND configuracion.activa;

    IF NOT FOUND THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        SELECT EXISTS (
            SELECT 1
            FROM auditoria.configuracion_columna AS seleccion
            JOIN auditoria.columna_auditada AS columna
                ON columna.id_columna = seleccion.id_columna
            WHERE seleccion.id_configuracion =
                  v_id_configuracion
              AND (
                  v_datos_anteriores
                      -> columna.nombre_columna
              ) IS DISTINCT FROM (
                  v_datos_nuevos
                      -> columna.nombre_columna
              )
        )
        INTO v_debe_registrar;

        IF NOT v_debe_registrar THEN
            RETURN NEW;
        END IF;
    END IF;

    v_usuario_aplicacion := NULLIF(
        btrim(
            current_setting(
                'autoaudit.usuario_aplicacion',
                true
            )
        ),
        ''
    );

    v_nombre_estacion := NULLIF(
        btrim(
            current_setting(
                'autoaudit.estacion',
                true
            )
        ),
        ''
    );

    v_nombre_aplicacion := NULLIF(
        btrim(
            current_setting(
                'application_name',
                true
            )
        ),
        ''
    );

    v_direccion_ip_texto := COALESCE(
        NULLIF(
            btrim(
                current_setting(
                    'autoaudit.ip_origen',
                    true
                )
            ),
            ''
        ),
        inet_client_addr()::text
    );

    IF v_direccion_ip_texto IS NOT NULL THEN
        BEGIN
            v_direccion_ip :=
                v_direccion_ip_texto::inet;
        EXCEPTION
            WHEN invalid_text_representation THEN
                v_direccion_ip :=
                    inet_client_addr();
        END;
    END IF;

    INSERT INTO auditoria.usuario_auditado (
        usuario_bd,
        usuario_aplicacion,
        nombre_mostrar,
        activo
    )
    VALUES (
        session_user,
        v_usuario_aplicacion,
        COALESCE(
            v_usuario_aplicacion,
            session_user
        ),
        true
    )
    ON CONFLICT (
        usuario_bd,
        usuario_aplicacion
    )
    DO UPDATE
    SET
        nombre_mostrar =
            EXCLUDED.nombre_mostrar,
        activo = true
    RETURNING id_usuario
    INTO v_id_usuario;

    IF v_direccion_ip IS NOT NULL
       OR v_nombre_estacion IS NOT NULL
       OR v_nombre_aplicacion IS NOT NULL THEN

        INSERT INTO auditoria.estacion_trabajo (
            direccion_ip,
            nombre_estacion,
            nombre_aplicacion
        )
        VALUES (
            v_direccion_ip,
            v_nombre_estacion,
            v_nombre_aplicacion
        )
        ON CONFLICT (
            direccion_ip,
            nombre_estacion,
            nombre_aplicacion
        )
        DO UPDATE
        SET ultima_conexion =
            clock_timestamp()
        RETURNING id_estacion
        INTO v_id_estacion;
    END IF;

    SELECT COALESCE(
        jsonb_object_agg(
            clave.nombre_columna,
            CASE
                WHEN TG_OP = 'DELETE'
                    THEN v_datos_anteriores
                         -> clave.nombre_columna
                ELSE v_datos_nuevos
                     -> clave.nombre_columna
            END
        ),
        '{}'::jsonb
    )
    INTO v_clave_registro
    FROM auditoria.v_claves_primarias AS clave
    WHERE clave.nombre_esquema = TG_TABLE_SCHEMA
      AND clave.nombre_tabla = TG_TABLE_NAME;

    INSERT INTO auditoria.bitacora (
        id_configuracion,
        id_usuario,
        id_estacion,
        operacion,
        id_transaccion,
        clave_registro,
        datos_anteriores,
        datos_nuevos
    )
    VALUES (
        v_id_configuracion,
        v_id_usuario,
        v_id_estacion,
        TG_OP,
        pg_current_xact_id()::text::bigint,
        v_clave_registro,
        v_datos_anteriores,
        v_datos_nuevos
    )
    RETURNING id_bitacora
    INTO v_id_bitacora;

    INSERT INTO auditoria.bitacora_detalle (
        id_bitacora,
        id_columna,
        valor_anterior,
        valor_nuevo,
        cambio
    )
    SELECT
        v_id_bitacora,
        columna.id_columna,
        CASE
            WHEN TG_OP = 'INSERT' THEN NULL
            ELSE v_datos_anteriores
                 -> columna.nombre_columna
        END,
        CASE
            WHEN TG_OP = 'DELETE' THEN NULL
            ELSE v_datos_nuevos
                 -> columna.nombre_columna
        END,
        CASE
            WHEN TG_OP IN ('INSERT', 'DELETE')
                THEN true
            ELSE (
                v_datos_anteriores
                    -> columna.nombre_columna
            ) IS DISTINCT FROM (
                v_datos_nuevos
                    -> columna.nombre_columna
            )
        END
    FROM auditoria.configuracion_columna AS seleccion
    JOIN auditoria.columna_auditada AS columna
        ON columna.id_columna = seleccion.id_columna
    WHERE seleccion.id_configuracion =
          v_id_configuracion;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION
            'AutoAudit no pudo registrar % sobre %.%: %',
            TG_OP,
            TG_TABLE_SCHEMA,
            TG_TABLE_NAME,
            SQLERRM;
END;
$$;

COMMENT ON FUNCTION auditoria.registrar_cambio() IS
    'Funcion central utilizada por los triggers de AutoAudit';

REVOKE ALL
    ON FUNCTION auditoria.registrar_cambio()
    FROM PUBLIC;

COMMIT;
