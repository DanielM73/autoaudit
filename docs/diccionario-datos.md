# Diccionario de datos de AutoAudit

Las tablas del sistema estarán dentro del esquema `auditoria`.

## tabla_auditada

Guarda las tablas seleccionadas para utilizar el sistema de auditoría.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_tabla | bigint | Llave primaria, identidad | Identificador de la tabla auditada |
| nombre_esquema | varchar(63) | No nulo | Esquema donde se encuentra la tabla |
| nombre_tabla | varchar(63) | No nulo | Nombre de la tabla |
| oid_tabla | oid | No nulo | Identificador interno de PostgreSQL |
| activa | boolean | No nulo, valor inicial true | Indica si la tabla continúa activa |
| fecha_registro | timestamptz | No nulo | Fecha de incorporación al sistema |

La combinación de `nombre_esquema` y `nombre_tabla` será única.

## columna_auditada

Guarda las columnas disponibles dentro de cada tabla auditada.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_columna | bigint | Llave primaria, identidad | Identificador de la columna |
| id_tabla | bigint | Llave foránea, no nulo | Tabla a la que pertenece |
| nombre_columna | varchar(63) | No nulo | Nombre de la columna |
| tipo_dato | text | No nulo | Tipo de dato encontrado en PostgreSQL |
| posicion | integer | No nulo | Posición de la columna dentro de la tabla |
| activa | boolean | No nulo, valor inicial true | Indica si la columna puede seguir auditándose |

La combinación de `id_tabla` y `nombre_columna` será única.

## tipo_evento

Contiene los tipos de operaciones reconocidas por el sistema.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_evento | smallint | Llave primaria, identidad | Identificador del evento |
| codigo | varchar(10) | Único, no nulo | INSERT, UPDATE o DELETE |
| descripcion | varchar(100) | No nulo | Explicación del evento |

## configuracion_auditoria

Define qué operación se auditará para una tabla.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_configuracion | bigint | Llave primaria, identidad | Identificador de la configuración |
| id_tabla | bigint | Llave foránea, no nulo | Tabla configurada |
| id_evento | smallint | Llave foránea, no nulo | Operación configurada |
| version | integer | No nulo | Versión de la configuración |
| activa | boolean | No nulo, valor inicial true | Indica si se encuentra habilitada |
| creada_por | varchar(63) | No nulo | Usuario que creó la configuración |
| fecha_creacion | timestamptz | No nulo | Fecha de creación |
| fecha_desactivacion | timestamptz | Puede ser nulo | Fecha en que fue desactivada |

Solo podrá existir una configuración activa por tabla y evento.

## configuracion_columna

Relaciona una configuración con las columnas que debe registrar.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_configuracion | bigint | Llave primaria y foránea | Configuración seleccionada |
| id_columna | bigint | Llave primaria y foránea | Columna seleccionada |

La llave primaria estará formada por ambos campos.

## usuario_auditado

Guarda la información de los usuarios que realizan cambios.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_usuario | bigint | Llave primaria, identidad | Identificador del usuario |
| usuario_bd | varchar(63) | No nulo | Usuario utilizado en PostgreSQL |
| usuario_aplicacion | varchar(100) | Puede ser nulo | Usuario autenticado en la aplicación |
| nombre_mostrar | varchar(150) | Puede ser nulo | Nombre utilizado en reportes |
| activo | boolean | No nulo, valor inicial true | Estado del usuario |
| fecha_registro | timestamptz | No nulo | Fecha del primer registro |

La combinación del usuario de base de datos y el usuario de aplicación será única.

## estacion_trabajo

Guarda información del lugar desde el cual se realizó una operación.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_estacion | bigint | Llave primaria, identidad | Identificador de la estación |
| direccion_ip | inet | Puede ser nulo | Dirección IP de origen |
| nombre_estacion | varchar(150) | Puede ser nulo | Nombre del equipo |
| nombre_aplicacion | varchar(150) | Puede ser nulo | Aplicación utilizada |
| primera_conexion | timestamptz | No nulo | Primera vez que fue detectada |
| ultima_conexion | timestamptz | No nulo | Última vez que fue utilizada |

## bitacora

Guarda la información general de cada operación auditada.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_bitacora | bigint | Llave primaria, identidad | Identificador del registro |
| id_configuracion | bigint | Llave foránea, no nulo | Configuración aplicada |
| id_usuario | bigint | Llave foránea, no nulo | Usuario responsable |
| id_estacion | bigint | Llave foránea, puede ser nulo | Estación de origen |
| operacion | varchar(10) | No nulo | INSERT, UPDATE o DELETE |
| fecha_evento | timestamptz | No nulo | Fecha y hora de la operación |
| id_transaccion | bigint | No nulo | Transacción de PostgreSQL |
| clave_registro | jsonb | No nulo | Llave primaria del registro modificado |
| datos_anteriores | jsonb | Puede ser nulo | Registro antes del cambio |
| datos_nuevos | jsonb | Puede ser nulo | Registro después del cambio |

## bitacora_detalle

Guarda los valores afectados en cada columna.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_detalle | bigint | Llave primaria, identidad | Identificador del detalle |
| id_bitacora | bigint | Llave foránea, no nulo | Registro general de bitácora |
| id_columna | bigint | Llave foránea, no nulo | Columna registrada |
| valor_anterior | jsonb | Puede ser nulo | Valor antes de la operación |
| valor_nuevo | jsonb | Puede ser nulo | Valor después de la operación |
| cambio | boolean | No nulo | Indica si el valor fue modificado |

La combinación de `id_bitacora` e `id_columna` será única.

## trigger_generado

Lleva el control de los triggers creados por el sistema.

| Campo | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_trigger | bigint | Llave primaria, identidad | Identificador del trigger |
| id_tabla | bigint | Llave foránea, no nulo | Tabla de origen |
| nombre_trigger | varchar(63) | No nulo | Nombre asignado al trigger |
| nombre_funcion | varchar(63) | No nulo | Función utilizada por el trigger |
| codigo_generado | text | No nulo | Código SQL generado |
| activo | boolean | No nulo, valor inicial true | Estado del trigger |
| fecha_generacion | timestamptz | No nulo | Fecha de generación |
