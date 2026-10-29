import os

import psycopg
from flask import g
from psycopg.rows import dict_row


VARIABLES_REQUERIDAS = (
    "DB_HOST",
    "DB_PORT",
    "DB_NAME",
    "DB_USER",
    "DB_PASSWORD",
)


def validar_configuracion():
    faltantes = [
        nombre
        for nombre in VARIABLES_REQUERIDAS
        if not os.getenv(nombre)
    ]

    if faltantes:
        nombres = ", ".join(faltantes)
        raise RuntimeError(
            f"Faltan variables de base de datos: {nombres}"
        )


def obtener_conexion():
    if "conexion_bd" not in g:
        validar_configuracion()

        g.conexion_bd = psycopg.connect(
            host=os.getenv("DB_HOST"),
            port=os.getenv("DB_PORT"),
            dbname=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            application_name="AutoAudit Web",
            connect_timeout=5,
            row_factory=dict_row,
        )

    return g.conexion_bd


def cerrar_conexion(error=None):
    conexion = g.pop("conexion_bd", None)

    if conexion is not None:
        if error is not None:
            conexion.rollback()

        conexion.close()


def obtener_estado_bd():
    conexion = obtener_conexion()

    with conexion.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                current_database() AS base_datos,
                current_user AS usuario,
                current_setting('server_version')
                    AS version_postgresql
            """
        )

        return cursor.fetchone()
