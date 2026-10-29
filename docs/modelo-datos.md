# Modelo de datos de AutoAudit

## Objetivo

El modelo de datos permitirá configurar qué tablas y columnas deben ser auditadas, generar los triggers necesarios y almacenar el historial de los cambios realizados.

La información del sistema se guardará dentro de un esquema llamado `auditoria`, separado de las tablas normales de la base de datos.

## Entidades principales

### tabla_auditada

Guarda las tablas que se han seleccionado para utilizar el sistema de auditoría. Se almacenará el nombre del esquema, el nombre de la tabla y su estado.

### columna_auditada

Guarda las columnas que pertenecen a cada tabla auditada. También almacenará su tipo de dato, posición y estado.

### tipo_evento

Contendrá los tres tipos de operaciones que puede registrar el sistema:

- INSERT
- UPDATE
- DELETE

### configuracion_auditoria

Relaciona una tabla auditada con el evento que se desea registrar. También permitirá activar o desactivar la configuración sin eliminarla.

### configuracion_columna

Indica cuáles columnas se deben registrar para cada configuración de auditoría.

### usuario_auditado

Guarda los usuarios que realizan cambios en las tablas. Permitirá consultar posteriormente todos los cambios realizados por un usuario específico.

### estacion_trabajo

Guarda información del equipo desde el cual se realizó una operación, como la dirección IP y el nombre de la aplicación o estación.

### bitacora

Guarda la información general de cada operación registrada, incluyendo la tabla, el evento, el usuario, la estación, la fecha, la clave del registro y los valores completos anteriores y nuevos.

### bitacora_detalle

Guarda el cambio realizado en cada columna. Esto permitirá consultar fácilmente el historial de una columna específica.

### trigger_generado

Lleva el control de los triggers creados por AutoAudit, incluyendo su nombre, la tabla a la que pertenece, la fecha de generación y su estado.

## Decisiones de diseño

Cada trigger trabajará únicamente con una tabla de origen.

Los valores anteriores y nuevos se almacenarán utilizando JSONB para poder auditar tablas con estructuras diferentes.

La bitácora no tendrá una llave foránea directa hacia el registro original. En su lugar guardará su clave primaria en formato JSONB. De esta manera, la información se conservará aunque el registro original sea eliminado.

Las configuraciones no se eliminarán físicamente. Se desactivarán para conservar la relación con los registros históricos.
