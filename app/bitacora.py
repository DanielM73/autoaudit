import csv
import io
import json
import math
from datetime import date
from zoneinfo import ZoneInfo

from flask import (
    Blueprint,
    abort,
    make_response,
    render_template,
    request,
)

from .auth import requiere_admin
from .db import obtener_conexion


bp = Blueprint("bitacora", __name__)

OPERACIONES_VALIDAS = ("INSERT", "UPDATE", "DELETE")
REGISTROS_POR_PAGINA = 25
ZONA_HORARIA = ZoneInfo("America/Guatemala")


def fecha_valida(valor):
    if not valor:
        return ""

    try:
        date.fromisoformat(valor)
        return valor
    except ValueError:
        return ""


def obtener_filtros():
    operacion = request.args.get("operacion", "").strip().upper()

    if operacion not in OPERACIONES_VALIDAS:
        operacion = ""

    return {
        "usuario": request.args.get("usuario", "").strip(),
        "esquema": request.args.get("esquema", "").strip(),
        "tabla": request.args.get("tabla", "").strip(),
        "columna": request.args.get("columna", "").strip(),
        "operacion": operacion,
        "fecha_desde": fecha_valida(
            request.args.get("fecha_desde", "").strip()
        ),
        "fecha_hasta": fecha_valida(
            request.args.get("fecha_hasta", "").strip()
        ),
    }


def construir_condiciones(filtros):
    condiciones = []
    parametros = []

    if filtros["usuario"]:
        patron = f"%{filtros['usuario']}%"

        condiciones.append(
            """
            (
                COALESCE(usuario.usuario_bd, '') ILIKE %s
                OR COALESCE(usuario.usuario_aplicacion, '') ILIKE %s
                OR COALESCE(usuario.nombre_mostrar, '') ILIKE %s
            )
            """
        )
        parametros.extend((patron, patron, patron))

    if filtros["esquema"]:
        condiciones.append("tabla.nombre_esquema = %s")
        parametros.append(filtros["esquema"])

    if filtros["tabla"]:
        condiciones.append("tabla.nombre_tabla = %s")
        parametros.append(filtros["tabla"])

    if filtros["operacion"]:
        condiciones.append("bitacora.operacion = %s")
        parametros.append(filtros["operacion"])

    if filtros["fecha_desde"]:
        condiciones.append("bitacora.fecha_evento >= %s::date")
        parametros.append(filtros["fecha_desde"])

    if filtros["fecha_hasta"]:
        condiciones.append(
            "bitacora.fecha_evento < (%s::date + INTERVAL '1 day')"
        )
        parametros.append(filtros["fecha_hasta"])

    if filtros["columna"]:
        condiciones.append(
            """
            EXISTS (
                SELECT 1
                FROM auditoria.bitacora_detalle AS detalle_filtro
                JOIN auditoria.columna_auditada AS columna_filtro
                    ON columna_filtro.id_columna =
                       detalle_filtro.id_columna
                WHERE detalle_filtro.id_bitacora =
                      bitacora.id_bitacora
                  AND columna_filtro.nombre_columna ILIKE %s
            )
            """
        )
        parametros.append(f"%{filtros['columna']}%")

    if not condiciones:
        return "", parametros

    return " WHERE " + " AND ".join(condiciones), parametros


def consulta_base():
    return """
        FROM auditoria.bitacora AS bitacora
        JOIN auditoria.configuracion_auditoria AS configuracion
            ON configuracion.id_configuracion =
               bitacora.id_configuracion
        JOIN auditoria.tabla_auditada AS tabla
            ON tabla.id_tabla = configuracion.id_tabla
        LEFT JOIN auditoria.usuario_auditado AS usuario
            ON usuario.id_usuario = bitacora.id_usuario
        LEFT JOIN auditoria.estacion_trabajo AS estacion
            ON estacion.id_estacion = bitacora.id_estacion
    """


def obtener_catalogos(conexion):
    tablas = conexion.execute(
        """
        SELECT DISTINCT
            tabla.nombre_esquema,
            tabla.nombre_tabla
        FROM auditoria.tabla_auditada AS tabla
        ORDER BY
            tabla.nombre_esquema,
            tabla.nombre_tabla
        """
    ).fetchall()

    columnas = conexion.execute(
        """
        SELECT DISTINCT
            columna.nombre_columna
        FROM auditoria.columna_auditada AS columna
        WHERE columna.activa = true
        ORDER BY columna.nombre_columna
        """
    ).fetchall()

    return tablas, columnas


@bp.get("/bitacora")
@requiere_admin
def lista():
    conexion = obtener_conexion()
    filtros = obtener_filtros()
    condiciones, parametros = construir_condiciones(filtros)

    pagina = request.args.get("pagina", 1, type=int)

    if pagina is None or pagina < 1:
        pagina = 1

    total = conexion.execute(
        "SELECT count(*) AS total "
        + consulta_base()
        + condiciones,
        parametros,
    ).fetchone()["total"]

    total_paginas = max(
        1,
        math.ceil(total / REGISTROS_POR_PAGINA),
    )

    pagina = min(pagina, total_paginas)
    desplazamiento = (
        pagina - 1
    ) * REGISTROS_POR_PAGINA

    registros = conexion.execute(
        """
        SELECT
            bitacora.id_bitacora,
            bitacora.operacion,
            bitacora.fecha_evento,
            to_char(
                bitacora.fecha_evento
                    AT TIME ZONE 'America/Guatemala',
                'DD/MM/YYYY HH24:MI:SS'
            ) AS fecha_local,
            bitacora.clave_registro,
            tabla.nombre_esquema,
            tabla.nombre_tabla,
            usuario.usuario_bd,
            usuario.usuario_aplicacion,
            usuario.nombre_mostrar,
            estacion.direccion_ip,
            estacion.nombre_estacion
        """
        + consulta_base()
        + condiciones
        + """
        ORDER BY
            bitacora.fecha_evento DESC,
            bitacora.id_bitacora DESC
        LIMIT %s
        OFFSET %s
        """,
        parametros
        + [
            REGISTROS_POR_PAGINA,
            desplazamiento,
        ],
    ).fetchall()

    tablas, columnas = obtener_catalogos(conexion)

    return render_template(
        "bitacora/lista.html",
        registros=registros,
        filtros=filtros,
        tablas=tablas,
        columnas=columnas,
        operaciones=OPERACIONES_VALIDAS,
        pagina=pagina,
        total_paginas=total_paginas,
        total=total,
    )


@bp.get("/bitacora/<int:id_bitacora>")
@requiere_admin
def detalle(id_bitacora):
    conexion = obtener_conexion()

    registro = conexion.execute(
        """
        SELECT
            bitacora.id_bitacora,
            bitacora.operacion,
            bitacora.fecha_evento,
            to_char(
                bitacora.fecha_evento
                    AT TIME ZONE 'America/Guatemala',
                'DD/MM/YYYY HH24:MI:SS'
            ) AS fecha_local,
            bitacora.id_transaccion,
            bitacora.clave_registro,
            bitacora.datos_anteriores,
            bitacora.datos_nuevos,
            configuracion.version,
            tabla.nombre_esquema,
            tabla.nombre_tabla,
            usuario.usuario_bd,
            usuario.usuario_aplicacion,
            usuario.nombre_mostrar,
            estacion.direccion_ip,
            estacion.nombre_estacion,
            estacion.nombre_aplicacion
        """
        + consulta_base()
        + """
        WHERE bitacora.id_bitacora = %s
        """,
        (id_bitacora,),
    ).fetchone()

    if registro is None:
        abort(404)

    cambios = conexion.execute(
        """
        SELECT
            detalle.id_detalle,
            columna.nombre_columna,
            columna.tipo_dato,
            detalle.valor_anterior,
            detalle.valor_nuevo,
            detalle.cambio
        FROM auditoria.bitacora_detalle AS detalle
        JOIN auditoria.columna_auditada AS columna
            ON columna.id_columna = detalle.id_columna
        WHERE detalle.id_bitacora = %s
        ORDER BY columna.posicion
        """,
        (id_bitacora,),
    ).fetchall()

    return render_template(
        "bitacora/detalle.html",
        registro=registro,
        cambios=cambios,
    )


@bp.get("/bitacora/exportar.csv")
@requiere_admin
def exportar():
    conexion = obtener_conexion()
    filtros = obtener_filtros()
    condiciones, parametros = construir_condiciones(filtros)

    registros = conexion.execute(
        """
        SELECT
            bitacora.id_bitacora,
            bitacora.fecha_evento,
            tabla.nombre_esquema,
            tabla.nombre_tabla,
            bitacora.operacion,
            usuario.usuario_bd,
            usuario.usuario_aplicacion,
            estacion.direccion_ip,
            estacion.nombre_estacion,
            bitacora.clave_registro,
            bitacora.datos_anteriores,
            bitacora.datos_nuevos
        """
        + consulta_base()
        + condiciones
        + """
        ORDER BY
            bitacora.fecha_evento,
            bitacora.id_bitacora
        """,
        parametros,
    ).fetchall()

    salida = io.StringIO()
    escritor = csv.writer(salida)

    escritor.writerow(
        [
            "ID",
            "Fecha y hora",
            "Esquema",
            "Tabla",
            "Operación",
            "Usuario de BD",
            "Usuario de aplicación",
            "Dirección IP",
            "Estación",
            "Clave del registro",
            "Datos anteriores",
            "Datos nuevos",
        ]
    )

    for registro in registros:
        fecha_local = registro["fecha_evento"].astimezone(
            ZONA_HORARIA
        )

        escritor.writerow(
            [
                registro["id_bitacora"],
                fecha_local.strftime("%d/%m/%Y %H:%M:%S"),
                registro["nombre_esquema"],
                registro["nombre_tabla"],
                registro["operacion"],
                registro["usuario_bd"] or "",
                registro["usuario_aplicacion"] or "",
                str(registro["direccion_ip"] or ""),
                registro["nombre_estacion"] or "",
                json.dumps(
                    registro["clave_registro"],
                    ensure_ascii=False,
                    default=str,
                ),
                json.dumps(
                    registro["datos_anteriores"],
                    ensure_ascii=False,
                    default=str,
                ),
                json.dumps(
                    registro["datos_nuevos"],
                    ensure_ascii=False,
                    default=str,
                ),
            ]
        )

    contenido = "\ufeff" + salida.getvalue()
    respuesta = make_response(contenido)

    respuesta.headers["Content-Type"] = (
        "text/csv; charset=utf-8"
    )
    respuesta.headers["Content-Disposition"] = (
        "attachment; filename=bitacora_autoaudit.csv"
    )

    return respuesta
