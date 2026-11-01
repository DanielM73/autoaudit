# Manual de instalación de AutoAudit

En este manual explicamos cómo instalar y ejecutar AutoAudit en Ubuntu. La idea es que cualquier integrante del grupo pueda descargar el proyecto y preparar su propia instalación siguiendo estos pasos.

## 1. Requisitos

Antes de comenzar se necesita lo siguiente:

- Ubuntu 26.04 LTS.
- PostgreSQL 18.
- Python 3.
- Git.
- Acceso al repositorio de GitHub.
- Al menos 2 GB de memoria RAM disponible.

## 2. Descargar el proyecto

El proyecto se puede descargar utilizando SSH:

```bash
git clone git@github.com:DanielM73/autoaudit.git
cd autoaudit
```

También se puede utilizar HTTPS:

```bash
git clone https://github.com/DanielM73/autoaudit.git
cd autoaudit
```

Como el repositorio puede estar configurado como privado, cada integrante debe tener permiso para acceder.

## 3. Instalar las herramientas

Primero actualizamos la lista de paquetes de Ubuntu:

```bash
sudo apt update
```

Luego instalamos Git, Python, el entorno virtual y el cliente de PostgreSQL:

```bash
sudo apt install git python3-pip python3-venv postgresql-client
```

Podemos verificar que todo quedó instalado con:

```bash
git --version
python3 --version
psql --version
```

## 4. Crear la base de datos

Entramos a PostgreSQL con el usuario administrador:

```bash
sudo -u postgres psql
```

Dentro de PostgreSQL creamos dos usuarios. El primero será el propietario de los objetos y el segundo será utilizado por la aplicación:

```sql
CREATE ROLE autoaudit_owner WITH LOGIN;
\password autoaudit_owner

CREATE ROLE autoaudit_app WITH LOGIN;
\password autoaudit_app
```

Luego creamos la base de datos:

```sql
CREATE DATABASE autoaudit_db
    WITH OWNER = autoaudit_owner
    ENCODING = 'UTF8'
    TEMPLATE = template0;
```

Limitamos los permisos generales y permitimos que la aplicación se conecte:

```sql
REVOKE ALL ON DATABASE autoaudit_db FROM PUBLIC;
GRANT CONNECT ON DATABASE autoaudit_db TO autoaudit_app;
```

Entramos a la base de datos:

```sql
\c autoaudit_db
```

Quitamos el permiso para crear objetos libremente y dejamos únicamente el permiso necesario para utilizar el esquema:

```sql
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO autoaudit_app;
```

Salimos de PostgreSQL:

```sql
\q
```

Las contraseñas utilizadas en este paso son privadas y no deben subirse al repositorio.

## 5. Preparar Python

Desde la carpeta principal de AutoAudit creamos el entorno virtual:

```bash
python3 -m venv .venv
```

Lo activamos con:

```bash
source .venv/bin/activate
```

Cuando está activo aparece `(.venv)` al inicio de la línea de la terminal.

Instalamos las dependencias del proyecto:

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## 6. Configurar el archivo .env

Creamos el archivo de configuración local a partir del ejemplo:

```bash
cp .env.example .env
```

Luego lo abrimos:

```bash
nano .env
```

El archivo debe tener esta estructura:

```text
FLASK_APP=run.py
FLASK_DEBUG=1
SECRET_KEY=clave-generada-localmente

DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=autoaudit_db
DB_USER=autoaudit_app
DB_PASSWORD=contraseña-de-autoaudit-app

ADMIN_USERNAME=admin
ADMIN_PASSWORD_HASH=hash-completo-de-la-contraseña
```

La clave secreta se puede generar con:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

Para crear el hash de la contraseña administrativa utilizamos:

```bash
python -c "from getpass import getpass; from werkzeug.security import generate_password_hash; clave=getpass('Contraseña administrativa: '); confirmacion=getpass('Confirmar contraseña: '); print(generate_password_hash(clave) if clave == confirmacion and clave else 'ERROR')"
```

Debemos copiar el hash completo en `ADMIN_PASSWORD_HASH`, incluyendo el texto inicial `scrypt:`.

En la pantalla de inicio de sesión se escribe la contraseña original. El hash solamente se guarda en el archivo `.env`.

Este archivo no se comparte ni se sube a GitHub porque contiene información privada.

## 7. Instalar la estructura de AutoAudit

El proyecto incluye un script que ejecuta los archivos SQL en el orden correcto.

Primero le damos permiso de ejecución:

```bash
chmod +x scripts/instalar_base_datos.sh
```

Después ejecutamos:

```bash
./scripts/instalar_base_datos.sh
```

El script solicita la contraseña de `autoaudit_owner`.

Durante la instalación se crean:

- El esquema central de auditoría.
- Las tablas y relaciones.
- Las vistas del diccionario de datos.
- Las funciones almacenadas.
- El generador de triggers.
- El esquema de demostración.
- Los datos iniciales de prueba.

Al terminar se muestra la cantidad de tablas creadas en los esquemas `auditoria` y `demo`.

## 8. Iniciar la aplicación

Para iniciar AutoAudit utilizamos:

```bash
chmod +x scripts/iniciar_aplicacion.sh
./scripts/iniciar_aplicacion.sh
```

También podemos iniciarlo manualmente:

```bash
source .venv/bin/activate
python run.py
```

La aplicación queda disponible en:

```text
http://127.0.0.1:5000
```

Para detener el servidor presionamos `Ctrl + C`.

## 9. Verificar la conexión

AutoAudit incluye una dirección que permite comprobar la conexión con PostgreSQL:

```text
http://127.0.0.1:5000/health
```

Si todo está funcionando correctamente, la respuesta muestra:

- Estado `ok`.
- Nombre de la base de datos.
- Usuario utilizado por la aplicación.
- Versión de PostgreSQL.

## 10. Iniciar sesión

Entramos a la aplicación desde el navegador y seleccionamos `Iniciar sesión`.

Utilizamos el usuario guardado en `ADMIN_USERNAME` y la contraseña original utilizada para generar el hash.

La contraseña y el hash no son lo mismo. El hash nunca debe escribirse en la pantalla de inicio de sesión.

## 11. Acceso de los integrantes del grupo

Todos los integrantes pueden consultar el código desde GitHub y clonar el repositorio en sus propias computadoras.

Para actualizar una copia existente se utiliza:

```bash
git pull origin main
```

Si otra computadora necesita entrar a la aplicación que está dentro de la máquina virtual, se puede configurar:

- Un adaptador de red puente.
- Reenvío de puertos en VirtualBox.
- Una dirección IP accesible dentro de la misma red.

La aplicación utiliza el puerto `5000`.

Este acceso debe habilitarse únicamente en una red controlada para realizar pruebas o la demostración.

El servidor incluido con Flask es suficiente para el desarrollo del proyecto, pero no está pensado para publicarse directamente en Internet.

## 12. Problemas comunes

### El comando python no funciona

Normalmente significa que el entorno virtual no está activo. Se soluciona con:

```bash
source .venv/bin/activate
```

### La aplicación no se conecta a PostgreSQL

Debemos revisar los datos guardados en `.env`, principalmente:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
```

`DB_PASSWORD` debe contener la contraseña de `autoaudit_app`.

### La contraseña de la base de datos fue olvidada

Podemos cambiarla entrando a PostgreSQL:

```bash
sudo -u postgres psql
```

Luego ejecutamos:

```sql
ALTER ROLE autoaudit_app
WITH PASSWORD 'nueva-contraseña';
```

Después actualizamos `DB_PASSWORD` en `.env`.

### El administrador no puede iniciar sesión

Debemos comprobar que:

- `ADMIN_USERNAME` tenga el usuario correcto.
- `ADMIN_PASSWORD_HASH` contenga el hash completo.
- El hash comience con `scrypt:`.
- En la pantalla se esté escribiendo la contraseña original.

Si es necesario, se puede generar un nuevo hash y reemplazar el anterior.

### El puerto 5000 está ocupado

Podemos comprobar qué proceso está utilizando el puerto:

```bash
ss -ltnp | grep 5000
```

Debemos detener el servidor anterior antes de iniciar otro.

### GitHub no acepta la conexión SSH

Podemos comprobar la llave con:

```bash
ssh -T git@github.com
```

Si no tenemos una llave configurada, podemos clonar el proyecto utilizando HTTPS.

## 13. Recomendaciones

- No subir el archivo `.env`.
- No compartir contraseñas ni hashes.
- Ejecutar `git pull` antes de comenzar a trabajar.
- Realizar commits pequeños y con mensajes claros.
- Probar los cambios antes de subirlos.
- Mantener una copia actualizada del proyecto en GitHub.
