import hmac
import os
import secrets
from functools import wraps

from flask import (
    Blueprint,
    abort,
    flash,
    redirect,
    render_template,
    request,
    session,
    url_for,
)
from werkzeug.security import check_password_hash


bp = Blueprint("auth", __name__)


def csrf_token():
    token = session.get("_csrf_token")

    if token is None:
        token = secrets.token_urlsafe(32)
        session["_csrf_token"] = token

    return token


def validar_csrf():
    token_guardado = session.get("_csrf_token", "")
    token_recibido = request.form.get("csrf_token", "")

    if (
        not token_guardado
        or not token_recibido
        or not hmac.compare_digest(
            token_guardado,
            token_recibido,
        )
    ):
        abort(400, description="Token de seguridad inválido")


def requiere_admin(vista):
    @wraps(vista)
    def vista_protegida(*args, **kwargs):
        if not session.get("admin_autenticado"):
            flash(
                "Debes iniciar sesión para continuar.",
                "warning",
            )

            return redirect(url_for("auth.login"))

        return vista(*args, **kwargs)

    return vista_protegida


@bp.route("/login", methods=("GET", "POST"))
def login():
    if session.get("admin_autenticado"):
        return redirect(url_for("main.inicio"))

    if request.method == "POST":
        validar_csrf()

        usuario = request.form.get("usuario", "").strip()
        clave = request.form.get("clave", "")

        usuario_configurado = os.getenv(
            "ADMIN_USERNAME",
            "",
        )

        hash_configurado = os.getenv(
            "ADMIN_PASSWORD_HASH",
            "",
        )

        usuario_valido = hmac.compare_digest(
            usuario,
            usuario_configurado,
        )

        try:
            clave_valida = bool(
                hash_configurado
            ) and check_password_hash(
                hash_configurado,
                clave,
            )
        except ValueError:
            clave_valida = False

        if usuario_valido and clave_valida:
            session.clear()
            session["admin_autenticado"] = True
            session["admin_usuario"] = usuario
            session.permanent = True

            flash(
                "Sesión administrativa iniciada.",
                "success",
            )

            return redirect(url_for("main.inicio"))

        flash(
            "El usuario o la contraseña no son correctos.",
            "danger",
        )

    return render_template("login.html")


@bp.post("/logout")
@requiere_admin
def logout():
    validar_csrf()
    session.clear()

    flash(
        "La sesión fue cerrada.",
        "success",
    )

    return redirect(url_for("auth.login"))
