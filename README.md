# CoachesOnlineDB – Explicación de archivos SQL
**TP Integrador – Ingeniería de Datos I – UADE**
Docente: Ing. Franco Salazar

---

## Orden de ejecución

El orden importa por dependencias entre objetos:

```
17b_crud_procedimientos.sql
17c_datos_prueba.sql
17d_ii_triggers.sql
17d_iii_vistas.sql
17d_iv_funcion_sp_complejo.sql
17d_i_consultas.sql
```

---

## `17b_crud_procedimientos.sql` — Procedimientos CRUD

22 stored procedures distribuidos en 11 tablas. Cada tabla tiene su propio bloque con comentarios que explican no solo qué hace cada SP, sino por qué está diseñado de esa forma. Hay tres patrones que se repiten a lo largo del archivo.

**Patrón ISNULL en UPDATE:** en vez de requerir todos los campos, cada SP de actualización acepta parámetros opcionales (`NULL` por defecto) y aplica `SET columna = ISNULL(@param, columna)`. Si el parámetro viene `NULL`, la columna se queda como estaba. Permite actualizaciones parciales sin conocer el estado actual del registro.

**Validación de negocio previa:** cada SP verifica condiciones de dominio antes de tocar la tabla (coach activo antes de insertar alumno, no tener rutina activa antes de crear una nueva, unicidad de email). Esto complementa los constraints de la BD con mensajes descriptivos via `RAISERROR`.

**Salida de ID con `SCOPE_IDENTITY()`:** todos los SPs de inserción retornan el ID generado como result set, útil para encadenar operaciones desde la capa de aplicación.

### SP por tabla

| SP | Operación | Descripción |
|----|-----------|-------------|
| `SP_InsertObjetivoEntrenamiento` | INSERT | Alta de objetivo con validación de nombre único. Retorna el ID generado. |
| `SP_ReadObjetivoEntrenamiento` | SELECT | Lectura de uno o todos los objetivos. Parámetro `@id` opcional: si es NULL devuelve todos usando el patrón `ISNULL(param, columna)`. |
| `SP_InsertNivelAlumno` | INSERT | Alta de nivel con validación de rango del porcentaje antes de insertar, complementando el CHECK constraint con un mensaje claro. |
| `SP_UpdateNivelAlumno` | UPDATE | Actualización parcial de porcentaje o descripción con patrón ISNULL. |
| `SP_InsertCoach` | INSERT | Alta de coach con validación de email único. El estado inicial siempre es Activo (1), no se expone como parámetro para evitar altas en estado incorrecto. |
| `SP_UpdateCoach` | UPDATE | Actualización parcial de cualquier campo. Si se cambia el email, verifica que no esté en uso por otro coach (consulta excluyendo el propio ID). |
| `SP_InsertAlumno` | INSERT | Alta de alumno con validación de coach activo. Regla de negocio: no se puede asignar un coach inactivo. El estado inicial siempre es Activo (1). |
| `SP_UpdateEstadoAlumno` | UPDATE | Cambio de estado del alumno (Activo / Pausado / Baja). Funciona como baja lógica cuando se pasa `id_estado_alumno = 3`. |
| `SP_InsertRutina` | INSERT | Alta de rutina activa. Verifica explícitamente si ya existe una rutina activa para ese alumno antes de insertar, dando un mensaje más descriptivo que la excepción de índice único. |
| `SP_UpdateRutina` | UPDATE | Actualización parcial de rutina: nombre, objetivo, estado y/o fecha de fin. Útil para finalizar una rutina pasando `id_estado_rutina = 2`. |
| `SP_InsertEjercicio` | INSERT | Alta de ejercicio con validación de nombre único. Descripción opcional. |
| `SP_UpdateEjercicio` | UPDATE | Actualización parcial de cualquier campo del ejercicio. Permite corregir nombres o reclasificar grupo muscular sin pasar todos los campos. |
| `SP_InsertRutinaEjercicio` | INSERT | Agrega un ejercicio a una rutina activa (prescripción). Valida que la rutina esté activa y que el ejercicio no esté ya incluido en ella. |
| `SP_UpdatePesoSugeridoRutinaEjercicio` | UPDATE | Actualiza el peso sugerido de una prescripción. Operación que también ejecuta el trigger automáticamente, pero se expone como SP para ajustes manuales del coach. |
| `SP_InsertSesionEntrenamiento` | INSERT | Registra una nueva sesión. Valida unicidad (alumno, fecha) con mensaje descriptivo. El trigger `TR_ValidarAlumnoActivoEnSesion` valida el estado del alumno. |
| `SP_UpdateEstadoSesion` | UPDATE | Modifica el estado de una sesión (Completa / Parcial / Cancelada) y opcionalmente los comentarios. |
| `SP_InsertRegistroEjercicio` | INSERT | Registra la ejecución de un ejercicio dentro de una sesión. Verifica la unicidad (sesión, rutina_ejercicio) antes de insertar. |
| `SP_DeleteRegistroEjercicio` | DELETE | Eliminación física de un registro de ejercicio. Única operación DELETE expuesta: permite corregir errores de carga sin dar de baja la sesión completa. |
| `SP_InsertSugerenciaProgresion` | INSERT | Crea una sugerencia de progresión. Valida que no haya otra Pendiente para la misma prescripción (complementa el índice filtrado) y que el peso sugerido no sea menor al actual. |
| `SP_ResolverSugerenciaProgresion` | UPDATE | Cambia el estado de una sugerencia Pendiente a Aprobada (2), Rechazada (3) o Aplicada (4). Solo acepta sugerencias en estado Pendiente. Si el destino es 4, el trigger actualiza automáticamente `RUTINA_EJERCICIO.peso_sugerido`. |
| `SP_InsertHistorialProgresion` | INSERT | Registra el resultado de la resolución de una sugerencia. Verifica que no exista ya un historial para esa sugerencia (restricción de unicidad). |
| `SP_ReadHistorialByAlumno` | SELECT | Historial completo de progresiones de un alumno. Navega la cadena HISTORIAL → SUGERENCIA → RUTINA_EJERCICIO → EJERCICIO → RUTINA → ALUMNO. Incluye `diferencia_kg` como columna calculada. Ordenado por fecha descendente. |

---

## `17c_datos_prueba.sql` — Datos de prueba

9 tablas, 117 filas en total. El orden de inserción respeta las dependencias de clave foránea. Cada bloque explica la lógica de los datos y las decisiones de diseño del dataset, no solo los valores. Se usa `SET IDENTITY_INSERT ON/OFF` para controlar los IDs explícitamente y garantizar que todas las referencias cruzadas sean correctas.

### Qué tiene cada tabla y por qué

**EJERCICIO (12 filas):** cubre los tipos más representativos del entrenamiento de fuerza e hipertrofia: movimientos compuestos (Sentadilla, Press Banca, Peso Muerto, Press Militar, Remo), peso corporal (Dominadas, Plancha), aislados (Hip Thrust, Curl, Extensión de Tríceps) y funcionales (Zancadas). La variedad permite demostrar consultas por grupo muscular y tipo.

**COACH (10 filas):** el coach 7 (Diego Fernández) está deliberadamente en estado Inactivo para demostrar la validación en `SP_InsertAlumno` y el trigger de sesiones. Ningún alumno del dataset le fue asignado.

**ALUMNO (10 filas):** distribuidos en tres niveles (Novato, Intermedio, Avanzado) y cinco objetivos distintos, todos con coach activo. El coach 7 queda sin alumnos para mostrar qué sucede con coaches inactivos en las consultas de conteo.

**RUTINA (12 filas):** las rutinas 1 y 2 son históricas (Finalizadas) para dar contexto temporal a los alumnos 1 y 2, que ya completaron un ciclo anterior. Las rutinas 3 a 12 son activas, una por alumno, respetando el índice único filtrado `UX_RUTINA_activa_por_alumno`.

**RUTINA_EJERCICIO (24 filas):** los pesos en `re2` (82.50 kg) y `re18` (115.00 kg) ya vienen con los valores post-aplicación porque las sugerencias `sug10` y `sug9` se insertan directamente como Aplicadas. El trigger que normalmente haría ese UPDATE no se disparó porque los datos se cargaron antes de crear el trigger.

**SESION_ENTRENAMIENTO (12 filas):** cubre los tres estados posibles. Las sesiones 6 y 9 son Parciales (menos registros que ejercicios en la rutina). La sesión 12 es Cancelada y no tiene registros asociados.

**REGISTRO_EJERCICIO (21 filas):** los registros muestran situaciones variadas: sesiones donde el alumno superó la carga objetivo (RIR por debajo del objetivo), sesiones exactas y sesiones incompletas. Esto genera datos realistas para las consultas de cumplimiento y volumen.

**SUGERENCIA_PROGRESION (10 filas):** cubre los 4 estados posibles. Los IDs están fuera de orden secuencial (sug7 y sug8 van después de sug6) deliberadamente para demostrar que la integridad depende de las FKs, no del orden de ID. Las cuatro Pendientes referencian rutinas_ejercicio distintas para respetar el índice filtrado único.

**HISTORIAL_PROGRESION (6 filas):** registra las resoluciones de las sugerencias no-Pendientes. Para rechazadas, `peso_nuevo = peso_anterior` (el rechazo no modifica la prescripción). Las cuatro sugerencias Pendientes aún no tienen historial porque están sin resolver.

---

## `17d_ii_triggers.sql` — Triggers

Los triggers se crean **después** de los datos de prueba para no interferir con las inserciones. Algunas filas del dataset (como `sug9` y `sug10` insertadas directamente como Aplicadas) no pasan por el flujo de UPDATE que activa el trigger 2.

### TR_ValidarAlumnoActivoEnSesion

**Tabla:** `SESION_ENTRENAMIENTO` | **Evento:** `AFTER INSERT`

Valida que el alumno tenga estado Activo (1) antes de permitir el registro de una sesión. Si la validación falla, hace `ROLLBACK TRANSACTION` para deshacer el INSERT completo y lanza un error descriptivo.

Usa `EXISTS` sobre la tabla virtual `inserted` con JOIN a `ALUMNO`, lo que lo hace correcto para inserción en batch: si se insertan múltiples sesiones a la vez, verifica todas las filas juntas, no fila a fila.

**Caso de prueba:**
```sql
EXEC dbo.SP_UpdateEstadoAlumno @id_alumno = 3, @id_estado_alumno = 3; -- Baja
EXEC dbo.SP_InsertSesionEntrenamiento @id_alumno = 3, @fecha = '2025-07-01'; -- falla
```

### TR_AplicarProgresionAlResolver

**Tabla:** `SUGERENCIA_PROGRESION` | **Evento:** `AFTER UPDATE`

Cuando el estado de una sugerencia cambia a Aplicada (4), actualiza automáticamente `RUTINA_EJERCICIO.peso_sugerido` con el peso aprobado en la sugerencia. Mantiene la sincronía sin requerir una segunda operación manual.

Tiene dos optimizaciones:

- `IF NOT UPDATE(id_estado_sugerencia) RETURN`: salida inmediata si el UPDATE tocó otra columna (por ejemplo, corrección del motivo). Evita trabajo innecesario.
- JOIN con `deleted` verificando que el estado anterior no sea 4: evita re-aplicación si la sugerencia ya estaba en estado Aplicada y se hace otro UPDATE sobre ella.

La actualización es set-based (opera sobre todas las filas a la vez), compatible con actualizaciones de múltiples sugerencias en lote.

**Caso de prueba:**
```sql
-- Resuelve sug7 (Pendiente → Aplicada). El trigger actualiza re4.peso_sugerido de 70 a 75.
EXEC dbo.SP_ResolverSugerenciaProgresion @id_sugerencia = 7, @id_estado_sugerencia = 4;
SELECT peso_sugerido FROM dbo.RUTINA_EJERCICIO WHERE id_rutina_ejercicio = 4;
```

---

## `17d_iii_vistas.sql` — Vistas

### VW_ResumenAlumno

Desnormaliza la información de 5 tablas en una sola vista orientada a listados generales. Evita que las capas superiores (aplicación, reportes) tengan que reescribir los mismos JOINs en cada consulta.

El JOIN con `RUTINA` es un `LEFT JOIN` filtrado por `id_estado_rutina = 1`. Esto garantiza que alumnos sin rutina activa igual aparezcan en la vista (con NULL en los campos de rutina), a diferencia de un INNER JOIN que los excluiría. El índice filtrado `UX_RUTINA_activa_por_alumno` garantiza que ese LEFT JOIN nunca retorne más de una fila por alumno.

**Uso típico:**
```sql
SELECT * FROM dbo.VW_ResumenAlumno WHERE estado_alumno = 'Activo';
SELECT * FROM dbo.VW_ResumenAlumno WHERE nivel = 'Avanzado' ORDER BY alumno;
```

### VW_SugerenciasPendientes

Encapsula 7 JOINs necesarios para ver el contexto completo de cada sugerencia pendiente: quién es el alumno, a qué nivel pertenece, qué ejercicio es, cuál es la prescripción actual (series/reps/rir) y qué cambio se propone (peso_actual → peso_sugerido con porcentaje).

El filtro `WHERE id_estado_sugerencia = 1` al final coincide con el índice filtrado `UX_SUGERENCIA_pendiente_por_prescripcion`, lo que hace la consulta eficiente. El valor de esta vista está en la reutilización: cualquier capa puede aplicar filtros adicionales sin reescribir los JOINs.

**Uso típico:**
```sql
SELECT * FROM dbo.VW_SugerenciasPendientes WHERE coach LIKE 'Ana%';
SELECT * FROM dbo.VW_SugerenciasPendientes WHERE nivel_alumno = 'Avanzado';
```

---

## `17d_iv_funcion_sp_complejo.sql` — Función escalar + SP complejo

### FN_VolumenSesion

Función escalar que calcula el volumen total de carga levantada en una sesión, definido como la suma de `(series × repeticiones × peso)` de todos los registros de ejercicio de esa sesión.

```
Volumen = Σ (series_realizadas × repeticiones_realizadas × peso_utilizado)
```

Usa `ISNULL(..., 0)` para retornar 0 en sesiones sin registros (canceladas o vacías), porque `SUM()` sobre un conjunto vacío retorna `NULL` en SQL Server. El `CAST` a `DECIMAL(12,2)` antes de multiplicar es necesario porque `INT × INT` puede truncar decimales.

El archivo incluye una nota sobre rendimiento: las funciones escalares se evalúan fila a fila. Para consultas masivas conviene pre-calcular los volúmenes en una subconsulta y usar la función una sola vez por sesión, como hace `SP_PanelCoach` en su RS3.

**Uso:**
```sql
SELECT dbo.FN_VolumenSesion(3)  AS volumen;  -- sesión completa: valor alto
SELECT dbo.FN_VolumenSesion(12) AS volumen;  -- sesión cancelada: 0
```

### SP_PanelCoach

SP complejo que devuelve 3 result sets en una sola ejecución, diseñados para alimentar un dashboard de gestión del coach.

**RS1 – Ficha del coach:** datos del coach más cantidad de alumnos activos. Usa LEFT JOIN con ALUMNO para que el COUNT retorne 0 si el coach no tiene alumnos activos (un INNER JOIN en ese caso no retornaría ninguna fila).

**RS2 – Estado de sus alumnos activos:** para cada alumno activo lista nivel, objetivo, última sesión, días sin actividad y cantidad de sugerencias pendientes. La columna `dias_sin_sesion` usa `DATEDIFF(DAY, MAX(fecha), GETDATE())` para calcular la inactividad en tiempo real. Las sugerencias pendientes se calculan con una subconsulta correlacionada que navega la cadena SUGERENCIA → RUTINA_EJERCICIO → RUTINA → ALUMNO. El resultado se ordena por `dias_sin_sesion DESC` para que los alumnos más inactivos aparezcan primero.

**RS3 – Estadísticas de sesiones con volumen:** agrupa sesiones por estado (Completa / Parcial / Cancelada) y calcula total, volumen total y volumen promedio. Para evitar llamar a `FN_VolumenSesion` dos veces por fila (una para `SUM`, otra para `AVG`), el volumen se pre-calcula en una subconsulta derivada. Luego la consulta exterior agrega sobre esos valores ya calculados.

---

## `17d_i_consultas.sql` — 12 consultas SQL

Cada consulta tiene un bloque de comentarios que explica propósito, técnica principal y decisiones de implementación.

### Q01 – Listado completo de alumnos

JOIN de 5 tablas. Devuelve el ecosistema completo de cada alumno en un resultado: estado, nivel, objetivo, coach y especialidad. El JOIN con `OBJETIVO_ENTRENAMIENTO` es LEFT JOIN porque el campo puede ser NULL. Se usa `ISNULL` para mostrar texto descriptivo en esos casos.

### Q02 – Coaches con alumnos activos

INNER JOIN con `ALUMNO` filtrado por `id_estado_alumno = 1` más `GROUP BY` y `HAVING COUNT >= 1`. El INNER JOIN ya excluye coaches sin alumnos activos; el HAVING es explícito para demostrar el uso de la cláusula. Ordenado por cantidad descendente.

### Q03 – Volumen por sesión

Llama a `FN_VolumenSesion` como columna calculada en el SELECT. Muestra cómo una función escalar se integra en una consulta normal. Sesiones completas con ejercicios pesados producen valores altos; sesiones canceladas producen 0.

### Q04 – Ejercicios con mayor volumen promedio

`AVG` de expresión aritmética (series × reps × peso) con `CAST` a DECIMAL para evitar truncamiento de enteros. Calcula el volumen promedio por registro para identificar los ejercicios de mayor carga relativa. Retorna los TOP 5 ordenados por promedio descendente.

### Q05 – Alumnos sin sesión en los últimos 30 días

Subconsulta `NOT IN`: la subconsulta devuelve los alumnos que SÍ tienen sesiones recientes; `NOT IN` excluye esos y devuelve solo los inactivos. Usa `DATEADD(DAY, -30, GETDATE())` como fecha de corte dinámica para que la consulta sea siempre vigente.

### Q06 – Sugerencias pendientes

Consulta directa sobre la vista `VW_SugerenciasPendientes`. Demuestra el valor de las vistas como capa de abstracción: 7 JOINs encapsulados en un `SELECT *` limpio con filtros opcionales.

### Q07 – TOP 5 ejercicios más prescriptos

`TOP 5` con `GROUP BY` y filtro de estado en el JOIN (`AND r.id_estado_rutina = 1`). Solo cuenta prescripciones de rutinas actualmente activas, excluyendo las finalizadas o pausadas. Identifica las tendencias de programación en el ciclo actual.

### Q08 – Porcentaje de cumplimiento de objetivos

Usa la vista `vw_RegistroEjercicioCumplimiento` del DDL original, que ya calcula `completado_calculado` (BIT). El `CAST` a INT permite sumar los 1s y 0s. `NULLIF(COUNT(*), 0)` previene la división por cero: si un alumno no tiene registros, el divisor se convierte en NULL y el resultado es NULL en vez de error.

### Q09 – Evolución de peso en Sentadilla del alumno 1

Filtro por nombre de ejercicio y alumno específico con `ORDER BY fecha ASC` para ver la progresión cronológica. Necesita navegar REGISTRO_EJERCICIO → RUTINA_EJERCICIO → EJERCICIO (para filtrar por nombre) y → SESION_ENTRENAMIENTO (para obtener la fecha). Muestra cómo se rastrea la evolución de carga de un ejercicio a lo largo del tiempo.

### Q10 – Estadísticas de sugerencias por nivel

`CASE` dentro de `SUM` para pivoteo manual por estado: equivalente a un COUNTIF de Excel, aplicado dentro de un GROUP BY. El porcentaje de aprobación incluye tanto Aprobadas (2) como Aplicadas (4) en el numerador, porque ambas representan sugerencias que el coach aceptó. Permite analizar si la política de progresión varía según el nivel del alumno.

### Q11 – Historial de progresiones con diferencia de peso

JOIN de 6 tablas que navega la cadena completa desde HISTORIAL hasta ALUMNO. La columna `diferencia_kg = peso_nuevo - peso_anterior` es calculada en el SELECT. Para sugerencias rechazadas el valor es 0 (el rechazo no cambia la prescripción); para aprobadas y aplicadas muestra el incremento real. Funciona como registro de auditoría de todas las decisiones de progresión.

### Q12 – Ranking de alumnos por volumen acumulado

`ROW_NUMBER() OVER (ORDER BY ...)` aplicado sobre una subconsulta derivada en el FROM. Necesita dos niveles porque las funciones de ventana no pueden combinarse con GROUP BY en el mismo SELECT: la subconsulta primero agrega (SUM, COUNT), y la consulta exterior aplica la ventana sobre ese resultado. Los LEFT JOINs con SESION y REGISTRO garantizan que todos los alumnos aparezcan en el ranking, incluso los que tienen volumen 0 (`ISNULL` convierte el NULL de SUM vacío en 0).