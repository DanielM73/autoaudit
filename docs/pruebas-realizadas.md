# Pruebas realizadas en AutoAudit

En este documento registramos las pruebas que realizamos durante el desarrollo de AutoAudit. Las pruebas se ejecutaron directamente sobre PostgreSQL y desde la interfaz web.

## 1. Ambiente utilizado

Las pruebas se realizaron con el siguiente ambiente:

- Ubuntu 26.04 LTS.
- PostgreSQL 18.6.
- Python 3.
- Flask 3.1.3.
- Psycopg 3.3.6.
- Máquina virtual de VirtualBox.
- 2 procesadores.
- Aproximadamente 3.3 GB de memoria RAM.

La base de datos utilizada fue:

```text
autoaudit_db
```

El usuario de conexión de la aplicación fue:

```text
autoaudit_app
```

## 2. Prueba de conexión

Se probó la conexión entre Flask y PostgreSQL mediante la dirección:

```text
http://127.0.0.1:5000/health
```

El servidor respondió correctamente con:

- Estado `ok`.
- Base de datos `autoaudit_db`.
- Usuario `autoaudit_app`.
- Versión de PostgreSQL 18.6.

Resultado: correcto.

## 3. Prueba del diccionario de datos

Se verificó que AutoAudit pudiera localizar las tablas y columnas del esquema de demostración.

Se encontraron las siguientes tablas:

- `demo.cliente`
- `demo.detalle_venta`
- `demo.producto`
- `demo.venta`

También se detectaron:

- 23 columnas.
- 4 llaves primarias.

Resultado: correcto.

## 4. Registro de una tabla

Se utilizó la función:

```sql
SELECT auditoria.registrar_tabla(
    'demo',
    'producto'
);
```

La tabla fue registrada con seis columnas:

- `id_producto`
- `nombre`
- `precio`
- `existencia`
- `activo`
- `fecha_actualizacion`

Resultado: correcto.

## 5. Configuración de eventos

Para la tabla `demo.producto` se configuraron los eventos:

- `INSERT`
- `UPDATE`
- `DELETE`

En `UPDATE` se seleccionaron las columnas:

- `precio`
- `existencia`

En `INSERT` y `DELETE` se seleccionaron todas las columnas.

Resultado: correcto.

## 6. Generación del trigger

Se ejecutó:

```sql
SELECT auditoria.generar_trigger(
    'demo',
    'producto'
);
```

El sistema generó:

```text
trg_autoaudit_1
```

La vista de triggers confirmó que se encontraba instalado y activo.

Resultado: correcto.

## 7. Prueba de UPDATE

Se modificó el producto `Mouse inalambrico`.

Los cambios fueron:

```text
Precio anterior: 175.50
Precio nuevo: 185.50
Existencia anterior: 35
Existencia nueva: 34
```

La bitácora registró:

- Operación `UPDATE`.
- Tabla `demo.producto`.
- Clave `id_producto = 2`.
- Usuario de base de datos.
- Usuario de aplicación.
- Dirección IP.
- Estación de trabajo.
- Valores anteriores.
- Valores nuevos.

El archivo utilizado fue:

```text
database/tests/001_prueba_update.sql
```

Resultado: correcto.

## 8. Prueba de INSERT

Se insertó el producto:

```text
Nombre: Audifonos USB
Precio: 225.00
Existencia: 15
```

La bitácora registró:

- Operación `INSERT`.
- Clave primaria generada.
- Datos nuevos.
- Seis detalles de columnas.
- Usuario e información de conexión.

Los datos anteriores quedaron vacíos, como corresponde a una inserción.

El archivo utilizado fue:

```text
database/tests/002_prueba_insert.sql
```

Resultado: correcto.

## 9. Prueba de DELETE

Se eliminó el producto `Audifonos USB`.

La prueba confirmó que:

- El producto fue eliminado de la tabla original.
- La información anterior se conservó en la bitácora.
- Los datos nuevos quedaron vacíos.
- Se conservaron los detalles de las seis columnas.

El archivo utilizado fue:

```text
database/tests/003_prueba_delete.sql
```

Resultado: correcto.

## 10. Prueba de rendimiento

Se realizaron 250 actualizaciones consecutivas sobre la tabla `demo.producto`.

Los resultados obtenidos fueron:

```text
Actualizaciones realizadas: 250
Tiempo total: 158.26 milisegundos
Tiempo promedio: 0.6330 milisegundos
Registros de auditoría generados: 250
Detalles generados: 500
```

La prueba se ejecutó dentro de una transacción y terminó con `ROLLBACK`.

La verificación mostró:

```text
rollback_correcto = true
```

Esto confirmó que los datos de prueba y los registros temporales no quedaron almacenados permanentemente.

El archivo utilizado fue:

```text
database/tests/004_prueba_rendimiento.sql
```

Resultado: correcto.

Los tiempos pueden cambiar dependiendo del equipo donde se ejecute la prueba.

## 11. Prueba de seguridad

Se comprobaron los permisos del usuario `autoaudit_app`.

Las verificaciones mostraron que:

- Puede conectarse a la base de datos.
- Puede utilizar el esquema de auditoría.
- Puede consultar la bitácora.
- No puede crear objetos libremente.
- No puede insertar directamente en la bitácora.
- No puede actualizar directamente la bitácora.
- No puede eliminar directamente de la bitácora.
- No puede ejecutar directamente la función interna del trigger.

Todas las operaciones no permitidas fueron rechazadas por PostgreSQL.

El archivo utilizado fue:

```text
database/tests/005_prueba_seguridad.sql
```

Resultado: correcto.

## 12. Prueba de inicio de sesión

Se generó una contraseña administrativa protegida con `scrypt`.

Se verificó que:

- Un usuario sin sesión no puede entrar a Configuración.
- Un usuario sin sesión no puede consultar la Bitácora.
- El administrador puede iniciar sesión con su contraseña.
- La aplicación no almacena la contraseña original.
- El cierre de sesión funciona mediante una solicitud protegida con CSRF.

Resultado: correcto.

## 13. Prueba de configuración web

Desde la interfaz se abrió la tabla `demo.producto`.

La aplicación mostró:

- Las seis columnas.
- Sus tipos de datos.
- La llave primaria.
- Las columnas obligatorias.
- Los eventos configurados.
- La versión de cada configuración.
- El trigger activo.

Se actualizó la configuración `INSERT` desde la interfaz.

La configuración cambió de la versión 1 a la versión 2 y el trigger fue regenerado.

Resultado: correcto.

## 14. Prueba de consulta de bitácora

La pantalla de Bitácora mostró los tres registros funcionales:

- `UPDATE`
- `INSERT`
- `DELETE`

Se abrió el detalle de `UPDATE` y se comprobaron:

- Datos del evento.
- Usuario.
- Dirección IP.
- Estación.
- Valores anteriores.
- Valores nuevos.
- Cambios por columna.

Resultado: correcto.

## 15. Prueba de filtros

Se aplicó el filtro por operación `UPDATE`.

La bitácora mostró únicamente el registro correspondiente a esa operación.

También se verificó que el sistema cuenta con filtros por:

- Usuario.
- Esquema.
- Tabla.
- Columna.
- Fecha inicial.
- Fecha final.

Resultado: correcto.

## 16. Prueba de exportación

Se exportó el resultado filtrado a:

```text
bitacora_autoaudit.csv
```

El archivo incluyó:

- Fecha y hora.
- Esquema.
- Tabla.
- Operación.
- Usuario.
- Dirección IP.
- Estación.
- Clave del registro.
- Datos anteriores.
- Datos nuevos.

El archivo pudo abrirse correctamente desde Ubuntu.

Resultado: correcto.

## 17. Resultado general

Las pruebas funcionales de `INSERT`, `UPDATE` y `DELETE` fueron completadas correctamente.

También fueron completadas las pruebas de:

- Rendimiento.
- Seguridad.
- Inicio de sesión.
- Configuración web.
- Consulta histórica.
- Filtros.
- Exportación.

Los resultados obtenidos muestran que AutoAudit cumple con las funciones principales planteadas para el proyecto.
