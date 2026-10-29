from flask import Blueprint, render_template

from .db import obtener_conexion


bp = Blueprint("main", __name__)


@bp.get("/")
def inicio():
    conexion = obtener_conexion()

    with conexion.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                (
                    SELECT count(*)
                    FROM auditoria.v_tablas_disponibles
                ) AS tablas_disponibles,
                (
                    SELECT count(*)
                    FROM auditoria.tabla_auditada
                    WHERE activa
                ) AS tablas_registradas,
                (
                    SELECT count(*)
                    FROM auditoria.configuracion_auditoria
                    WHERE activa
                ) AS configuraciones_activas,
                (
                    SELECT count(*)
                    FROM auditoria.trigger_generado
                    WHERE activo
                ) AS triggers_activos,
                (
                    SELECT count(*)
                    FROM auditoria.bitacora
                ) AS cambios_registrados
            """
        )

        resumen = cursor.fetchone()

        cursor.execute(
            """
            SELECT
                bitacora.id_bitacora,
                tabla.nombre_esquema
                    || '.'
                    || tabla.nombre_tabla
                    AS tabla,
                bitacora.operacion,
                bitacora.fecha_evento AT TIME ZONE 'America/Guatemala' AS fecha_evento,
                usuario.nombre_mostrar AS usuario,
                bitacora.clave_registro
            FROM auditoria.bitacora AS bitacora
            JOIN auditoria.configuracion_auditoria
                AS configuracion
                ON configuracion.id_configuracion =
                   bitacora.id_configuracion
            JOIN auditoria.tabla_auditada AS tabla
                ON tabla.id_tabla =
                   configuracion.id_tabla
            JOIN auditoria.usuario_auditado AS usuario
                ON usuario.id_usuario =
                   bitacora.id_usuario
            ORDER BY bitacora.id_bitacora DESC
            LIMIT 5
            """
        )

        cambios_recientes = cursor.fetchall()

    return render_template(
        "dashboard.html",
        resumen=resumen,
        cambios_recientes=cambios_recientes,
    )
