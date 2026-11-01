# AutoAudit

AutoAudit es un sistema configurable de auditoría automática para PostgreSQL.

El proyecto permite seleccionar las tablas, columnas y operaciones que se desean auditar. A partir de esa configuración se generan triggers dinámicos que registran los cambios en una bitácora centralizada.

## Funciones principales

- Detección de tablas y columnas mediante el diccionario de datos.
- Configuración de auditoría para `INSERT`, `UPDATE` y `DELETE`.
- Selección de las columnas que deben ser auditadas.
- Generación dinámica de triggers.
- Un trigger de auditoría por cada tabla configurada.
- Registro de filas anteriores y nuevas.
- Registro detallado de cambios por columna.
- Registro de usuario, fecha, hora, dirección IP y estación.
- Historial de versiones de las configuraciones.
- Panel principal con el estado del sistema.
- Acceso administrativo con contraseña protegida.
- Consulta de la bitácora mediante filtros.
- Vista detallada de cada cambio.
- Exportación de reportes en formato CSV.
- Pruebas funcionales, de rendimiento y de seguridad.

## Tecnologías utilizadas

- Ubuntu 26.04 LTS.
- PostgreSQL 18.
- PL/pgSQL.
- Python 3.
- Flask.
- Psycopg.
- HTML.
- CSS.
- Bootstrap 5.
- Git y GitHub.

## Estructura del proyecto

```text
autoaudit/
├── app/
│   ├── static/
│   ├── templates/
│   ├── auth.py
│   ├── bitacora.py
│   ├── configuracion.py
│   ├── db.py
│   └── routes.py
├── database/
│   ├── ddl/
│   ├── functions/
│   ├── queries/
│   ├── seeds/
│   └── tests/
├── docs/
│   ├── diagramas/
│   ├── diccionario-datos.md
│   ├── manual-instalacion.md
│   ├── manual-usuario.md
│   ├── modelo-datos.md
│   └── pruebas-realizadas.md
├── scripts/
│   ├── iniciar_aplicacion.sh
│   └── instalar_base_datos.sh
├── .env.example
├── requirements.txt
└── run.py
```

## Instalación

Las instrucciones completas se encuentran en:

```text
docs/manual-instalacion.md
```

De forma resumida, primero se clona el proyecto:

```bash
git clone git@github.com:DanielM73/autoaudit.git
cd autoaudit
```

Luego se crea y activa el entorno virtual:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Se instalan las dependencias:

```bash
pip install -r requirements.txt
```

Se crea el archivo de configuración privado:

```bash
cp .env.example .env
nano .env
```

Después de crear la base de datos y sus usuarios, se instala la estructura:

```bash
./scripts/instalar_base_datos.sh
```

Finalmente se inicia la aplicación:

```bash
./scripts/iniciar_aplicacion.sh
```

## Acceso

La aplicación se abre en:

```text
http://127.0.0.1:5000
```

El estado de la conexión puede comprobarse en:

```text
http://127.0.0.1:5000/health
```

## Pruebas

Los archivos de prueba se encuentran en:

```text
database/tests/
```

Se incluyen pruebas para:

- Auditoría de `UPDATE`.
- Auditoría de `INSERT`.
- Auditoría de `DELETE`.
- Rendimiento con 250 actualizaciones.
- Restricciones de seguridad.

Los resultados obtenidos se encuentran documentados en:

```text
docs/pruebas-realizadas.md
```

## Seguridad

La aplicación utiliza dos usuarios de PostgreSQL:

- `autoaudit_owner`: propietario de los objetos.
- `autoaudit_app`: usuario limitado utilizado por Flask.

`autoaudit_app` puede consultar la bitácora, pero no puede insertar, modificar ni eliminar directamente sus registros.

Las configuraciones se realizan mediante funciones controladas y la función interna del trigger no puede ejecutarse directamente desde la aplicación.

Las contraseñas y claves privadas se guardan solamente en `.env`, archivo que no se incluye en Git.

## Documentación

El repositorio incluye:

- Modelo de datos.
- Diagrama entidad-relación.
- Diccionario de datos.
- Manual de instalación.
- Manual de usuario.
- Registro de pruebas realizadas.

## Estado del proyecto

Las funciones principales de AutoAudit ya fueron implementadas y probadas.

El sistema permite configurar auditorías, generar triggers, registrar cambios, consultar el historial y exportar reportes.
