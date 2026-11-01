import psycopg
from flask import (
    Blueprint,
    abort,
    flash,
    redirect,
    render_template,
    request,
    url_for,
)

from .auth import requiere_admin, validar_csrf
from .db import obtener_conexion


bp = Blueprint("configuracion", __name__)

EVENTOS_VALIDOS = ("INSERT", "UPDATE", "DELETE")


def mensaje_error(error):
    mensaje = getattr(error.diag, "message_primary", None)
    return mensaje or str(error)


def verificar_tabla(nombre_esquema, nombre_tabla):
    conexion = obtener_conexion()

    fila = conexion.execute(
        """
        SELECT 1
        FROM auditoria.v_tablas_disponibles
        WHERE nombre_esquema = %s
          AND nombre_tabla = %s
        """,
        (nombre_esquema, nombre_tabla),
    ).fetchone()

    if fila is None:
        abort(404)


@bp.get("/configuracion")
@requiere_admin
def lista():
    conexion = obtener_conexion()

    tablas = conexion.execute(
        """
        SELECT
            tabla.nombre_esquema,
            tabla.nombre_tabla,
            COALESCE(
                (
                    SELECT array_agg(
                        configuracion.evento
                        ORDER BY configuracion.evento
                    )
                    FROM auditoria.v_configuracion_actual AS configuracion
                    WHERE configuracion.nombre_esquema =
                          tabla.nombre_esquema
                      AND configuracion.nombre_tabla =
                          tabla.nombre_tabla
                ),
                ARRAY[]::text[]
            ) AS eventos,
            EXISTS (
                SELECT 1
                FROM auditoria.v_triggers_activos AS trigger
                WHERE trigger.nombre_esquema =
                      tabla.nombre_esquema
                  AND trigger.nombre_tabla =
                      tabla.nombre_tabla
                  AND trigger.instalado = true
            ) AS trigger_instalado
        FROM auditoria.v_tablas_disponibles AS tabla
        ORDER BY
            tabla.nombre_esquema,
            tabla.nombre_tabla
        """
    ).fetchall()

    return render_template(
        "configuracion/lista.html",
        tablas=tablas,
    )


@bp.get("/configuracion/<nombre_esquema>/<nombre_tabla>")
@requiere_admin
def editar(nombre_esquema, nombre_tabla):
    verificar_tabla(nombre_esquema, nombre_tabla)
    conexion = obtener_conexion()

    columnas = conexion.execute(
        """
        SELECT
            columna.column_name AS nombre_columna,
            columna.data_type AS tipo_dato,
            columna.is_nullable = 'YES' AS permite_nulos,
            EXISTS (
                SELECT 1
                FROM auditoria.v_claves_primarias AS clave
                WHERE clave.nombre_esquema = columna.table_schema
                  AND clave.nombre_tabla = columna.table_name
                  AND clave.nombre_columna = columna.column_name
            ) AS es_clave_primaria
        FROM information_schema.columns AS columna
        WHERE columna.table_schema = %s
          AND columna.table_name = %s
        ORDER BY columna.ordinal_position
        """,
        (nombre_esquema, nombre_tabla),
    ).fetchall()

    filas_configuracion = conexion.execute(
        """
        SELECT
            evento,
            version,
            columnas
        FROM auditoria.v_configuracion_actual
        WHERE nombre_esquema = %s
          AND nombre_tabla = %s
        ORDER BY evento
        """,
        (nombre_esquema, nombre_tabla),
    ).fetchall()

    configuraciones = {
        fila["evento"]: fila
        for fila in filas_configuracion
    }

    trigger = conexion.execute(
        """
        SELECT
            nombre_trigger,
            instalado,
            fecha_generacion
        FROM auditoria.v_triggers_activos
        WHERE nombre_esquema = %s
          AND nombre_tabla = %s
        ORDER BY fecha_generacion DESC
        LIMIT 1
        """,
        (nombre_esquema, nombre_tabla),
    ).fetchone()

    return render_template(
        "configuracion/editar.html",
        nombre_esquema=nombre_esquema,
        nombre_tabla=nombre_tabla,
        columnas=columnas,
        eventos=EVENTOS_VALIDOS,
        configuraciones=configuraciones,
        trigger=trigger,
    )


@bp.post("/configuracion/<nombre_esquema>/<nombre_tabla>")
@requiere_admin
def guardar(nombre_esquema, nombre_tabla):
    validar_csrf()
    verificar_tabla(nombre_esquema, nombre_tabla)

    evento = request.form.get("evento", "").strip().upper()
    columnas = [
        columna.strip()
        for columna in request.form.getlist("columnas")
        if columna.strip()
    ]

    if evento not in EVENTOS_VALIDOS:
        flash("El tipo de evento seleccionado no es válido.", "danger")
        return redirect(
            url_for(
                "configuracion.editar",
                nombre_esquema=nombre_esquema,
                nombre_tabla=nombre_tabla,
            )
        )

    conexion = obtener_conexion()

    columnas_validas = conexion.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = %s
          AND table_name = %s
        """,
        (nombre_esquema, nombre_tabla),
    ).fetchall()

    nombres_validos = {
        fila["column_name"]
        for fila in columnas_validas
    }

    if any(columna not in nombres_validos for columna in columnas):
        flash("Se recibió una columna que no pertenece a la tabla.", "danger")
        return redirect(
            url_for(
                "configuracion.editar",
                nombre_esquema=nombre_esquema,
                nombre_tabla=nombre_tabla,
            )
        )

    try:
        resultado = conexion.execute(
            """
            SELECT auditoria.configurar_auditoria(
                %s,
                %s,
                %s,
                %s
            ) AS id_configuracion
            """,
            (
                nombre_esquema,
                nombre_tabla,
                evento,
                columnas or None,
            ),
        ).fetchone()

        trigger = conexion.execute(
            """
            SELECT auditoria.generar_trigger(
                %s,
                %s
            ) AS nombre_trigger
            """,
            (nombre_esquema, nombre_tabla),
        ).fetchone()

        conexion.commit()

        flash(
            (
                f"Se configuró el evento {evento}. "
                f"Configuración #{resultado['id_configuracion']} y "
                f"trigger {trigger['nombre_trigger']} actualizados."
            ),
            "success",
        )

    except psycopg.Error as error:
        conexion.rollback()
        flash(
            f"No se pudo guardar la configuración: {mensaje_error(error)}",
            "danger",
        )

    return redirect(
        url_for(
            "configuracion.editar",
            nombre_esquema=nombre_esquema,
            nombre_tabla=nombre_tabla,
        )
    )


@bp.post(
    "/configuracion/<nombre_esquema>/<nombre_tabla>/desactivar"
)
@requiere_admin
def desactivar(nombre_esquema, nombre_tabla):
    validar_csrf()
    verificar_tabla(nombre_esquema, nombre_tabla)

    evento = request.form.get("evento", "").strip().upper()

    if evento not in EVENTOS_VALIDOS:
        flash("El tipo de evento seleccionado no es válido.", "danger")
        return redirect(
            url_for(
                "configuracion.editar",
                nombre_esquema=nombre_esquema,
                nombre_tabla=nombre_tabla,
            )
        )

    conexion = obtener_conexion()

    try:
        conexion.execute(
            """
            SELECT auditoria.desactivar_auditoria(
                %s,
                %s,
                %s
            )
            """,
            (nombre_esquema, nombre_tabla, evento),
        )

        conexion.execute(
            """
            SELECT auditoria.generar_trigger(
                %s,
                %s
            )
            """,
            (nombre_esquema, nombre_tabla),
        )

        conexion.commit()

        flash(
            f"Se desactivó la auditoría para el evento {evento}.",
            "success",
        )

    except psycopg.Error as error:
        conexion.rollback()
        flash(
            f"No se pudo desactivar la configuración: {mensaje_error(error)}",
            "danger",
        )

    return redirect(
        url_for(
            "configuracion.editar",
            nombre_esquema=nombre_esquema,
            nombre_tabla=nombre_tabla,
        )
    )
