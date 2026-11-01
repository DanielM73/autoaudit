# Manual de usuario de AutoAudit

Este manual explica cómo utilizar las funciones principales de AutoAudit desde la interfaz web.

El sistema permite configurar tablas y columnas, generar triggers automáticos, consultar los cambios registrados y exportar la bitácora.

## 1. Iniciar la aplicación

Desde la carpeta principal del proyecto activamos el entorno virtual:

```bash
source .venv/bin/activate
```

Luego iniciamos el servidor:

```bash
./scripts/iniciar_aplicacion.sh
```

También podemos utilizar:

```bash
python run.py
```

Abrimos el navegador e ingresamos a:

```text
http://127.0.0.1:5000
```

## 2. Panel principal

Al entrar en AutoAudit se muestra el panel principal.

En este panel podemos ver un resumen del estado actual del sistema:

- Tablas disponibles.
- Tablas registradas para auditoría.
- Configuraciones activas.
- Triggers instalados.
- Cambios almacenados en la bitácora.

También se muestran los cambios más recientes, indicando:

- Número del registro.
- Tabla modificada.
- Tipo de operación.
- Usuario.
- Clave del registro.
- Fecha y hora.

Este panel permite revisar rápidamente si el sistema está funcionando y si se están registrando cambios.

## 3. Iniciar sesión

Para utilizar la configuración y consultar la bitácora debemos iniciar sesión.

Seleccionamos `Iniciar sesión` en el menú superior.

Ingresamos:

- El usuario administrativo configurado en `.env`.
- La contraseña original utilizada para generar el hash.

No debemos ingresar el hash en la pantalla. El hash se utiliza únicamente dentro del archivo `.env`.

Si los datos son correctos, el menú mostrará:

- Inicio.
- Configuración.
- Bitácora.
- Nombre del usuario.
- Cerrar sesión.

## 4. Configuración de auditoría

Entramos a la opción `Configuración`.

La pantalla muestra las tablas encontradas mediante el diccionario de datos de PostgreSQL.

Para cada tabla podemos ver:

- Nombre del esquema.
- Nombre de la tabla.
- Eventos configurados.
- Estado del trigger.
- Botón para configurar.

Los eventos disponibles son:

- `INSERT`: registra filas nuevas.
- `UPDATE`: registra modificaciones.
- `DELETE`: registra filas eliminadas.

## 5. Seleccionar una tabla

Buscamos la tabla que deseamos auditar y presionamos `Configurar`.

AutoAudit muestra:

- Nombre de la tabla.
- Nombre del trigger.
- Estado del trigger.
- Fecha de la última generación.
- Columnas disponibles.
- Tipos de datos.
- Llave primaria.
- Columnas obligatorias.

Las configuraciones se encuentran separadas en tres secciones: `INSERT`, `UPDATE` y `DELETE`.

## 6. Activar un evento

Para activar la auditoría de un evento:

1. Buscamos la sección del evento.
2. Seleccionamos las columnas que deseamos guardar.
3. Presionamos el botón para activar el evento.

Por ejemplo, para registrar cambios de precio y existencia:

1. Entramos a la tabla `demo.producto`.
2. Buscamos la sección `UPDATE`.
3. Seleccionamos `precio`.
4. Seleccionamos `existencia`.
5. Presionamos `Activar UPDATE`.

AutoAudit guarda la configuración y genera el trigger de la tabla automáticamente.

## 7. Seleccionar columnas

Podemos seleccionar cada columna de forma individual.

También existen dos botones:

- `Seleccionar todas`.
- `Quitar selección`.

Si no seleccionamos ninguna columna, AutoAudit interpreta que se deben auditar todas las columnas de la tabla.

En una operación `UPDATE`, normalmente conviene seleccionar solamente las columnas importantes para evitar guardar información innecesaria.

## 8. Actualizar una configuración

Si un evento ya está configurado, el botón cambia a `Actualizar`.

Podemos marcar o desmarcar columnas y guardar nuevamente.

Cada cambio crea una nueva versión de la configuración. Las versiones anteriores se conservan para mantener el historial de los registros ya almacenados.

Después de guardar, el trigger se vuelve a generar para utilizar la configuración más reciente.

## 9. Desactivar un evento

Para dejar de auditar un evento:

1. Entramos a la configuración de la tabla.
2. Buscamos el evento.
3. Presionamos `Desactivar`.
4. Confirmamos la operación.

La configuración queda desactivada y el trigger se actualiza.

Desactivar un evento no elimina los registros históricos que ya existen en la bitácora.

## 10. Consultar la bitácora

Entramos a la opción `Bitácora` del menú.

La pantalla muestra todos los cambios registrados, ordenados desde el más reciente hasta el más antiguo.

Para cada cambio se muestra:

- ID de bitácora.
- Fecha y hora.
- Tabla.
- Operación.
- Usuario.
- Clave del registro.
- Dirección IP.
- Enlace para ver el detalle.

Los registros no pueden modificarse ni eliminarse desde la aplicación.

## 11. Utilizar los filtros

La bitácora permite filtrar la información por:

- Usuario.
- Esquema.
- Tabla.
- Columna.
- Operación.
- Fecha inicial.
- Fecha final.

Después de seleccionar los filtros presionamos `Buscar`.

Para eliminar todos los filtros presionamos `Limpiar`.

### Ejemplo de búsqueda por operación

Para consultar solamente actualizaciones:

1. Seleccionamos `UPDATE` en el campo Operación.
2. Presionamos `Buscar`.

La tabla mostrará únicamente los registros correspondientes a actualizaciones.

### Ejemplo de búsqueda por usuario

Escribimos el nombre del usuario de PostgreSQL o de la aplicación y presionamos `Buscar`.

La búsqueda acepta coincidencias parciales.

### Ejemplo de búsqueda por columna

Seleccionamos una columna, como `precio`, y presionamos `Buscar`.

El sistema mostrará únicamente los registros que tengan detalles asociados con esa columna.

## 12. Ver el detalle de un cambio

En la bitácora presionamos `Ver detalle`.

La pantalla muestra la información completa del evento:

- Tabla modificada.
- Fecha y hora.
- Operación.
- Versión de la configuración.
- Número de transacción.
- Clave primaria del registro.
- Usuario de PostgreSQL.
- Usuario de la aplicación.
- Dirección IP.
- Estación de trabajo.
- Aplicación utilizada.

También se muestra una tabla con los cambios por columna:

- Nombre de la columna.
- Tipo de dato.
- Valor anterior.
- Valor nuevo.
- Confirmación de que el valor cambió.

En la parte inferior se muestran las filas completas antes y después de la operación.

## 13. Interpretar las operaciones

### INSERT

En un registro `INSERT`:

- Los datos anteriores aparecen vacíos.
- Los datos nuevos contienen la fila creada.

### UPDATE

En un registro `UPDATE`:

- Los datos anteriores muestran la fila antes del cambio.
- Los datos nuevos muestran la fila después del cambio.
- El detalle indica las columnas modificadas.

### DELETE

En un registro `DELETE`:

- Los datos anteriores contienen la fila eliminada.
- Los datos nuevos aparecen vacíos.
- La información permanece en la bitácora aunque la fila original ya no exista.

## 14. Exportar un reporte

La bitácora puede exportarse a un archivo CSV.

Primero aplicamos los filtros que necesitemos y luego presionamos `Exportar CSV`.

El navegador descargará:

```text
bitacora_autoaudit.csv
```

El archivo incluye:

- ID.
- Fecha y hora.
- Esquema.
- Tabla.
- Operación.
- Usuario de PostgreSQL.
- Usuario de aplicación.
- Dirección IP.
- Estación.
- Clave del registro.
- Datos anteriores.
- Datos nuevos.

La exportación respeta los filtros seleccionados.

El archivo puede abrirse con LibreOffice Calc, Microsoft Excel o cualquier programa compatible con CSV.

## 15. Cerrar sesión

Cuando terminamos de utilizar las funciones administrativas presionamos `Cerrar sesión`.

La sesión también tiene un tiempo limitado por seguridad.

Después de cerrar sesión todavía podemos ver el panel principal, pero no podemos cambiar configuraciones ni consultar la bitácora sin volver a identificarnos.

## 16. Recomendaciones de uso

- No compartir la contraseña administrativa.
- Cerrar sesión al terminar.
- Auditar solamente las columnas necesarias.
- Revisar que el trigger aparezca como activo.
- Aplicar filtros antes de exportar reportes grandes.
- No modificar directamente las tablas del esquema `auditoria`.
- Realizar pruebas antes de utilizar una tabla nueva.
- Mantener actualizada la copia del proyecto.

## 17. Flujo recomendado para una demostración

Para demostrar el funcionamiento del proyecto podemos seguir este orden:

1. Iniciar sesión.
2. Mostrar el panel principal.
3. Entrar a Configuración.
4. Seleccionar la tabla `demo.producto`.
5. Mostrar los eventos y columnas configurados.
6. Realizar un `INSERT`, `UPDATE` o `DELETE`.
7. Entrar a la Bitácora.
8. Buscar el cambio recién realizado.
9. Abrir el detalle.
10. Mostrar los valores anteriores y nuevos.
11. Aplicar un filtro.
12. Exportar el resultado a CSV.

Con este flujo se pueden mostrar las funciones principales de AutoAudit de forma clara y ordenada.
