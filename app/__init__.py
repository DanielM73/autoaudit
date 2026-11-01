import os
from datetime import timedelta

import psycopg
from dotenv import load_dotenv
from flask import Flask, jsonify

from .auth import bp as auth_bp, csrf_token
from .configuracion import bp as configuracion_bp
from .bitacora import bp as bitacora_bp
from .db import cerrar_conexion, obtener_estado_bd
from .routes import bp as main_bp


def create_app():
    load_dotenv()

    app = Flask(__name__)

    clave_secreta = os.getenv("SECRET_KEY")

    if not clave_secreta:
        raise RuntimeError(
            "No se encontró SECRET_KEY en el archivo .env"
        )

    app.config["SECRET_KEY"] = clave_secreta
    app.config["SESSION_COOKIE_HTTPONLY"] = True
    app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
    app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(hours=2)

    app.teardown_appcontext(cerrar_conexion)
    app.register_blueprint(auth_bp)
    app.register_blueprint(configuracion_bp)
    app.register_blueprint(bitacora_bp)
    app.register_blueprint(main_bp)
    app.jinja_env.globals["csrf_token"] = csrf_token

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
