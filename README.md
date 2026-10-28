# AutoAudit

AutoAudit es un proyecto del curso de Base de Datos. La idea es desarrollar un sistema que permita llevar un registro de los cambios realizados en una base de datos PostgreSQL.

El sistema permitirá elegir qué tablas y columnas se quieren auditar. A partir de esa configuración se generarán triggers para registrar automáticamente las operaciones INSERT, UPDATE y DELETE.

## Qué vamos a desarrollar

- Configuración de las tablas y columnas que se desean auditar.
- Selección de las operaciones INSERT, UPDATE y DELETE.
- Generación automática de triggers.
- Registro de los valores anteriores y nuevos.
- Registro del usuario, fecha, hora, dirección IP y estación de trabajo.
- Consultas de los cambios por usuario, tabla o columna.
- Exportación de los resultados.
- Pruebas funcionales y de rendimiento.

## Tecnologías que utilizaremos

- Ubuntu 26.04 LTS
- PostgreSQL 18
- PL/pgSQL
- Python 3
- Flask
- HTML, CSS y Bootstrap
- Git y GitHub

## Estado del proyecto

Actualmente el proyecto se encuentra en desarrollo. Los diferentes módulos se irán agregando y probando de forma gradual.
