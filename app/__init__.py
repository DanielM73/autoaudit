import os

import psycopg
from dotenv import load_dotenv
from flask import Flask, jsonify

from .db import cerrar_conexion, obtener_estado_bd


def create_app():
    load_dotenv()

    app = Flask(__name__)

    clave_secreta = os.getenv("SECRET_KEY")

    if not clave_secreta:
        raise RuntimeError(
            "No se encontró SECRET_KEY en el archivo .env"
        )

    app.config["SECRET_KEY"] = clave_secreta

    app.teardown_appcontext(cerrar_conexion)

    @app.get("/health")
    def health():
        try:
            estado = obtener_estado_bd()
        except psycopg.Error:
            app.logger.exception(
                "No fue posible conectar con PostgreSQL"
            )

            return jsonify(
                estado="error",
                mensaje="No fue posible conectar con PostgreSQL",
            ), 503

        return jsonify(
            estado="ok",
            aplicacion="AutoAudit",
            base_datos=estado["base_datos"],
            usuario=estado["usuario"],
            postgresql=estado["version_postgresql"],
        )

    return app
