USE CoachesOnlineDB;
GO

/*
=============================================================
  SECCIÓN 17d – SCRIPT ÚNICO: SOPORTE + CONSULTAS SQL (12)
  TP Integrador – Ingeniería de Datos I – UADE
  Docente: Ing. Franco Salazar

  ESTE ARCHIVO REEMPLAZA a los tres scripts separados
  (17d_iv_funcion_sp_complejo.sql, 17d_iii_vistas.sql,
  17d_i_consultas.sql) y los fusiona en uno solo, en el
  orden correcto de ejecución, para poder correr todo con
  un solo F5 sin depender de abrir varias pestañas.

  ORDEN INTERNO DE ESTE ARCHIVO (importa, no reordenar):
    PARTE 1 – Función dbo.FN_VolumenSesion   (requerida por Q03)
    PARTE 2 – Vista  dbo.VW_SugerenciasPendientes (requerida por Q06)
    PARTE 3 – Las 12 consultas (Q01 a Q12)

  POR QUÉ ESTE ORDEN:
    SQL Server resuelve los objetos referenciados (funciones, vistas)
    al momento de ejecutar cada SELECT, no al momento de "compilar"
    todo el archivo. Si Q03 o Q06 se ejecutan antes de que la función
    o la vista existan en la base, fallan con "Invalid object name"
    aunque estén definidas más abajo en el mismo archivo. Por eso la
    función y la vista van primero.

  DEPENDENCIA EXTERNA QUE SIGUE EXISTIENDO:
    Este script asume que ya ejecutaste antes el DDL de creación de
    la base (tablas, dominios, vw_RegistroEjercicioCumplimiento) y,
    si querés ver filas en los resultados, también los datos de
    prueba (17c_datos_prueba.sql). Sin datos, las consultas corren
    sin error pero pueden devolver 0 filas (por ejemplo Q09, que
    depende de un alumno id=1 y un ejercicio llamado 'Sentadilla').

  Índice de consultas:
    Q01 – Listado completo de alumnos con coach, nivel y objetivo
    Q02 – Coaches con alumnos activos (GROUP BY + HAVING)
    Q03 – Volumen por sesión usando FN_VolumenSesion
    Q04 – Ejercicios con mayor volumen promedio
    Q05 – Alumnos sin sesión en los últimos 30 días
    Q06 – Sugerencias pendientes (via vista)
    Q07 – TOP 5 ejercicios más prescriptos en rutinas activas
    Q08 – % cumplimiento de objetivos por alumno
    Q09 – Evolución de peso en Sentadilla del alumno 1
    Q10 – Estadísticas de sugerencias por nivel de alumno
    Q11 – Historial de progresiones con diferencia de peso
    Q12 – Ranking de alumnos por volumen acumulado (ROW_NUMBER)
=============================================================
*/


/* ============================================================
   PARTE 1 – FUNCIÓN: dbo.FN_VolumenSesion
   ============================================================

   PROPÓSITO:
     Esta función no existía en el DDL original y es una
     dependencia obligatoria de Q03, que la invoca como
     dbo.FN_VolumenSesion(se.id_sesion).

   POR QUÉ SE ENCAPSULA COMO FUNCIÓN Y NO COMO SUBCONSULTA INLINE:
     Q03 pide explícitamente demostrar el uso de una función
     escalar definida por usuario (UDF). Encapsular la fórmula
     evita reescribir SUM(series*reps*peso) en cada consulta que
     necesite el volumen de una sesión, centralizando el cálculo
     en un solo lugar (la misma fórmula se reutiliza en Q04 y Q12).
*/

DROP FUNCTION IF EXISTS dbo.FN_VolumenSesion;
GO

CREATE FUNCTION dbo.FN_VolumenSesion (@id_sesion INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    /*
        Variable de retorno inicializada en 0.
        POR QUÉ: si la sesión no tiene registros asociados (por ejemplo,
        una sesión Cancelada, que por regla de negocio no carga
        REGISTRO_EJERCICIO), el SELECT INTO de abajo no actualiza
        @volumen y la función debe devolver 0 en lugar de NULL.
        Devolver NULL rompería ORDER BY y cualquier comparación
        numérica posterior (ej. WHERE volumen > 0) en las consultas
        que la usan.
    */
    DECLARE @volumen DECIMAL(12,2) = 0;

    /*
        Misma fórmula que ya usan Q04 y Q12: series * reps * peso,
        casteado a DECIMAL antes de multiplicar.
        POR QUÉ EL CAST: en SQL Server, INT * INT produce INT y trunca
        cualquier decimal intermedio antes de aplicar el peso (que sí
        es DECIMAL). Castear series_realizadas y repeticiones_realizadas
        a DECIMAL(10,2) antes de multiplicar evita esa truncación y
        mantiene la fórmula consistente con el resto del set de consultas.

        SELECT ... INTO en vez de RETURN directo: es la única forma
        permitida dentro de una función escalar en T-SQL para asignar
        el resultado de una agregación (SUM) a una variable.
    */
    SELECT
        @volumen = ISNULL(SUM(
            CAST(re.series_realizadas       AS DECIMAL(10,2)) *
            CAST(re.repeticiones_realizadas AS DECIMAL(10,2)) *
            re.peso_utilizado
        ), 0)
    FROM dbo.REGISTRO_EJERCICIO re
    WHERE re.id_sesion = @id_sesion;

    RETURN @volumen;
END;
GO


/* ============================================================
   PARTE 2 – VISTA: dbo.VW_SugerenciasPendientes
   ============================================================

   PROPÓSITO:
     Esta vista no existía en el DDL original y es una
     dependencia obligatoria de Q06, que hace
     SELECT * FROM dbo.VW_SugerenciasPendientes.

   POR QUÉ SE ENCAPSULA EN UNA VISTA Y NO SE DEJA TODO EN Q06:
     Una sugerencia de progresión pendiente necesita atravesar la
     cadena SUGERENCIA_PROGRESION → ESTADO_SUGERENCIA →
     RUTINA_EJERCICIO → EJERCICIO → RUTINA → ALUMNO → NIVEL_ALUMNO
     → COACH para mostrar contexto completo (alumno, nivel, coach,
     ejercicio, pesos). Definir esos 7 JOINs una sola vez en la
     vista evita repetirlos en cada consulta o pantalla que
     necesite este panel de revisión.

   POR QUÉ FILTRA id_estado_sugerencia = 1 DENTRO DE LA VISTA:
     El nombre de la vista indica su propósito específico: mostrar
     solo lo que requiere acción del coach. Filtrar "Pendiente"
     (id 1, según la carga de ESTADO_SUGERENCIA en el DDL) dentro
     de la vista evita que cada consultante deba recordar agregar
     ese WHERE manualmente.
*/

DROP VIEW IF EXISTS dbo.VW_SugerenciasPendientes;
GO

CREATE VIEW dbo.VW_SugerenciasPendientes
AS
SELECT
    sp.id_sugerencia,
    sp.fecha_sugerencia,
    es.nombre_estado                 AS estado_sugerencia,

    -- Datos del alumno y su coach, para que el panel sea autocontenido
    -- y no requiera otro JOIN externo al consultarlo (ver Q06).
    a.id_alumno,
    a.nombre + N' ' + a.apellido     AS alumno,
    na.nombre_nivel                  AS nivel_alumno,
    c.nombre + N' ' + c.apellido     AS coach,

    -- Ejercicio afectado por la sugerencia.
    e.id_ejercicio,
    e.nombre                         AS ejercicio,
    e.grupo_muscular,

    -- Detalle numérico de la sugerencia en sí.
    sp.peso_actual,
    sp.peso_sugerido,
    sp.porcentaje_incremento,
    sp.motivo,

    /*
        Columna calculada: diferencia absoluta entre peso sugerido
        y peso actual. POR QUÉ: ahorra que cada consumidor de la
        vista (ej. una UI de revisión) tenga que restar los dos
        campos manualmente para mostrar "+2.5 kg" en pantalla.
    */
    sp.peso_sugerido - sp.peso_actual AS incremento_kg

FROM  dbo.SUGERENCIA_PROGRESION    sp
INNER JOIN dbo.ESTADO_SUGERENCIA    es ON es.id_estado_sugerencia   = sp.id_estado_sugerencia
INNER JOIN dbo.RUTINA_EJERCICIO     re ON re.id_rutina_ejercicio    = sp.id_rutina_ejercicio
INNER JOIN dbo.EJERCICIO            e  ON e.id_ejercicio            = re.id_ejercicio
INNER JOIN dbo.RUTINA                r ON r.id_rutina               = re.id_rutina
INNER JOIN dbo.ALUMNO                a ON a.id_alumno               = r.id_alumno
INNER JOIN dbo.NIVEL_ALUMNO         na ON na.id_nivel_alumno        = a.id_nivel_alumno
INNER JOIN dbo.COACH                 c ON c.id_coach                = a.id_coach

/*
    Filtro fijo en la definición de la vista (no en Q06): solo
    sugerencias en estado "Pendiente". El id 1 corresponde a
    'Pendiente' según la carga de ESTADO_SUGERENCIA en el DDL
    base; se referencia por id en vez de comparar contra el
    nombre por performance (evita un JOIN/lookup de string) y
    porque la tabla de dominio garantiza que ese id es estable.
*/
WHERE sp.id_estado_sugerencia = 1;
GO


/* ============================================================
   PARTE 3 – LAS 12 CONSULTAS
   ============================================================ */


-- ── Q01 ──────────────────────────────────────────────────────────────
/*
  Listado completo de alumnos con coach, nivel, objetivo y estado.

  Técnica principal: JOIN múltiple (5 tablas).
  Propósito         : Vista de gestión general. Permite ver el ecosistema
                      de cada alumno en un solo resultado.

  JOINs:
    ALUMNO ──INNER──> ESTADO_ALUMNO           (estado del alumno)
    ALUMNO ──INNER──> NIVEL_ALUMNO            (nivel de progresión)
    ALUMNO ──LEFT───> OBJETIVO_ENTRENAMIENTO  (puede ser NULL)
    ALUMNO ──INNER──> COACH                   (coach asignado)

  ISNULL en objetivo: el campo id_objetivo_entrenamiento admite NULL,
  por lo que se reemplaza con texto descriptivo para mejor legibilidad.
*/
SELECT
    a.id_alumno,
    a.nombre + N' ' + a.apellido    AS alumno,
    ea.nombre_estado                AS estado,
    na.nombre_nivel                 AS nivel,
    ISNULL(oe.nombre_objetivo, N'Sin objetivo') AS objetivo,
    c.nombre  + N' ' + c.apellido   AS coach,
    c.especialidad,
    a.fecha_alta
FROM  dbo.ALUMNO              a
INNER JOIN dbo.ESTADO_ALUMNO  ea ON ea.id_estado_alumno          = a.id_estado_alumno
INNER JOIN dbo.NIVEL_ALUMNO   na ON na.id_nivel_alumno           = a.id_nivel_alumno
LEFT  JOIN dbo.OBJETIVO_ENTRENAMIENTO oe
                              ON oe.id_objetivo_entrenamiento    = a.id_objetivo_entrenamiento
INNER JOIN dbo.COACH          c  ON c.id_coach                  = a.id_coach
ORDER BY c.apellido, a.apellido;
GO


-- ── Q02 ──────────────────────────────────────────────────────────────
/*
  Coaches con al menos 1 alumno activo y su conteo.

  Técnica principal: GROUP BY + HAVING + INNER JOIN (filtro implícito).
  Propósito         : Identifica qué coaches tienen actividad actual.
                      Útil para detectar coaches sin carga de trabajo.

  INNER JOIN con ALUMNO + filtro AND id_estado_alumno = 1:
    Solo cuenta alumnos activos. Los coaches que no tengan ningún
    alumno activo quedan excluidos por el INNER JOIN.
  HAVING COUNT >= 1:
    Explícito para mostrar el uso de HAVING, aunque en este caso
    el INNER JOIN ya garantiza que el conteo sea >= 1.
*/
SELECT
    c.id_coach,
    c.nombre + N' ' + c.apellido   AS coach,
    c.especialidad,
    COUNT(a.id_alumno)             AS alumnos_activos
FROM  dbo.COACH   c
INNER JOIN dbo.ALUMNO a ON a.id_coach = c.id_coach AND a.id_estado_alumno = 1
GROUP BY c.id_coach, c.nombre, c.apellido, c.especialidad
HAVING COUNT(a.id_alumno) >= 1
ORDER BY alumnos_activos DESC;
GO


-- ── Q03 ──────────────────────────────────────────────────────────────
/*
  Volumen total por sesión usando la función escalar FN_VolumenSesion.

  Técnica principal: llamada a función escalar definida por usuario (UDF).
  Propósito         : Muestra el volumen de trabajo de cada sesión de
                      forma legible, sin reescribir la fórmula SUM().

  FN_VolumenSesion(id_sesion):
    Encapsula Σ(series × reps × peso) y retorna 0 para sesiones
    sin registros (canceladas). Aparece en la lista SELECT como
    si fuera una columna calculada. Definida en la PARTE 1 de
    este mismo script, antes de esta consulta.

  Resultado esperado:
    Sesiones completas con varios ejercicios pesados (ej.: alumno 8)
    mostrarán volúmenes altos. Sesiones parciales y canceladas, bajos o 0.
*/
SELECT
    se.id_sesion,
    se.fecha,
    a.nombre + N' ' + a.apellido   AS alumno,
    es.nombre_estado               AS estado_sesion,
    dbo.FN_VolumenSesion(se.id_sesion) AS volumen_kg
FROM  dbo.SESION_ENTRENAMIENTO se
INNER JOIN dbo.ALUMNO          a  ON a.id_alumno         = se.id_alumno
INNER JOIN dbo.ESTADO_SESION   es ON es.id_estado_sesion = se.id_estado_sesion
ORDER BY se.fecha DESC;
GO


-- ── Q04 ──────────────────────────────────────────────────────────────
/*
  TOP 5 ejercicios con mayor volumen promedio por registro.

  Técnica principal: AVG de expresión aritmética + TOP + GROUP BY.
  Propósito         : Identifica qué ejercicios concentran más carga
                      de trabajo en promedio. Útil para análisis de
                      distribución del entrenamiento.

  AVG(series × reps × peso):
    Se calcula el promedio del volumen de cada registro individual,
    no el volumen total acumulado. Esto normaliza por frecuencia y
    da una idea del peso relativo de cada ejercicio en cada aparición.
  CAST a DECIMAL: necesario porque la multiplicación entre INT e INT
    produce INT en SQL Server, truncando decimales.
*/
SELECT TOP 5
    e.nombre                       AS ejercicio,
    e.grupo_muscular,
    COUNT(re.id_registro)          AS veces_registrado,
    CAST(AVG(
        CAST(re.series_realizadas       AS DECIMAL(10,2)) *
        CAST(re.repeticiones_realizadas AS DECIMAL(10,2)) *
        re.peso_utilizado
    ) AS DECIMAL(10,2))            AS volumen_promedio_kg
FROM  dbo.REGISTRO_EJERCICIO re
INNER JOIN dbo.RUTINA_EJERCICIO rue ON rue.id_rutina_ejercicio = re.id_rutina_ejercicio
INNER JOIN dbo.EJERCICIO         e  ON e.id_ejercicio          = rue.id_ejercicio
GROUP BY e.id_ejercicio, e.nombre, e.grupo_muscular
ORDER BY volumen_promedio_kg DESC;
GO


-- ── Q05 ──────────────────────────────────────────────────────────────
/*
  Alumnos activos sin sesión registrada en los últimos 30 días.

  Técnica principal: subconsulta NOT EXISTS.
  Propósito         : Detecta alumnos con poca adherencia al entrenamiento.
                      Permite al coach identificar quién necesita seguimiento.

  POR QUÉ NOT EXISTS Y NO NOT IN:
    id_alumno en SESION_ENTRENAMIENTO es NOT NULL (FK obligatoria),
    así que NOT IN tampoco hubiera fallado acá. Aun así se usa
    NOT EXISTS porque es más robusto ante cambios futuros del
    esquema y porque SQL Server suele resolverlo con mejor plan
    de ejecución (semi-join) que materializar toda la lista de
    IDs como hace NOT IN.

  DATEADD(DAY, -30, ...):
    Calcula la fecha de corte 30 días atrás desde hoy.
*/
SELECT
    a.id_alumno,
    a.nombre + N' ' + a.apellido   AS alumno,
    na.nombre_nivel                AS nivel,
    c.nombre + N' ' + c.apellido   AS coach
FROM  dbo.ALUMNO            a
INNER JOIN dbo.NIVEL_ALUMNO na ON na.id_nivel_alumno = a.id_nivel_alumno
INNER JOIN dbo.COACH         c ON c.id_coach         = a.id_coach
WHERE  a.id_estado_alumno = 1   -- solo alumnos activos
  AND  NOT EXISTS (
        SELECT 1
        FROM   dbo.SESION_ENTRENAMIENTO se
        WHERE  se.id_alumno = a.id_alumno
          AND  se.fecha >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
      )
ORDER BY a.apellido;
GO


-- ── Q06 ──────────────────────────────────────────────────────────────
/*
  Sugerencias pendientes con contexto completo.

  Técnica principal: consulta sobre vista (VW_SugerenciasPendientes).
  Propósito         : Panel de revisión para coaches. La vista encapsula
                      7 JOINs, simplificando la consulta de uso frecuente.

  Uso de la vista:
    Demuestra el valor de abstraer lógica de acceso compleja en una vista
    reutilizable. Definida en la PARTE 2 de este mismo script, antes
    de esta consulta.
*/
SELECT *
FROM   dbo.VW_SugerenciasPendientes
ORDER BY fecha_sugerencia;
GO


-- ── Q07 ──────────────────────────────────────────────────────────────
/*
  TOP 5 ejercicios más prescriptos en rutinas activas.

  Técnica principal: TOP + GROUP BY + filtro de estado en JOIN.
  Propósito         : Muestra qué ejercicios tienen mayor presencia
                      en las rutinas en curso. Útil para análisis de
                      tendencias de programación.

  Filtro de JOIN con RUTINA:
    La condición AND r.id_estado_rutina = 1 en el INNER JOIN asegura
    que solo se cuenten prescripciones de rutinas actualmente activas,
    excluyendo las finalizadas o pausadas.
*/
SELECT TOP 5
    e.nombre          AS ejercicio,
    e.grupo_muscular,
    e.tipo_ejercicio,
    COUNT(*)          AS veces_prescripto
FROM  dbo.RUTINA_EJERCICIO re
INNER JOIN dbo.RUTINA    r ON r.id_rutina    = re.id_rutina   AND r.id_estado_rutina = 1
INNER JOIN dbo.EJERCICIO e ON e.id_ejercicio = re.id_ejercicio
GROUP BY e.id_ejercicio, e.nombre, e.grupo_muscular, e.tipo_ejercicio
ORDER BY veces_prescripto DESC;
GO


-- ── Q08 ──────────────────────────────────────────────────────────────
/*
  Porcentaje de cumplimiento de objetivos por alumno.

  Técnica principal: CASE via vista + NULLIF para división segura.
  Propósito         : Mide qué porcentaje de los ejercicios registrados
                      se completaron según el objetivo de series y reps.

  vw_RegistroEjercicioCumplimiento:
    Vista del DDL original que calcula completado_calculado (BIT):
    1 si series_realizadas >= series_objetivo Y reps_realizadas >= reps_objetivo.
  NULLIF(COUNT(*), 0):
    Previene división por cero en caso de que un alumno no tenga registros,
    convirtiendo 0 en NULL, lo que hace que la división resulte en NULL
    en vez de error.
*/
SELECT
    a.id_alumno,
    a.nombre + N' ' + a.apellido                AS alumno,
    COUNT(*)                                    AS total_registros,
    SUM(CAST(v.completado_calculado AS INT))    AS registros_completados,
    CAST(
        100.0 * SUM(CAST(v.completado_calculado AS INT))
              / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    )                                           AS pct_cumplimiento
FROM  dbo.vw_RegistroEjercicioCumplimiento v
INNER JOIN dbo.ALUMNO a ON a.id_alumno = v.id_alumno
GROUP BY a.id_alumno, a.nombre, a.apellido
ORDER BY pct_cumplimiento DESC;
GO


-- ── Q09 ──────────────────────────────────────────────────────────────
/*
  Evolución histórica del peso en Sentadilla del alumno 1.

  Técnica principal: filtro por nombre de ejercicio + ORDER BY fecha.
  Propósito         : Muestra la progresión de carga a lo largo del tiempo
                      para un ejercicio específico de un alumno específico.
                      Permite visualizar el avance en una línea temporal.

  JOINs necesarios:
    REGISTRO_EJERCICIO → RUTINA_EJERCICIO → EJERCICIO (para filtrar por nombre)
    REGISTRO_EJERCICIO → SESION_ENTRENAMIENTO         (para obtener la fecha)
  Filtros:
    se.id_alumno = 1  : limita al alumno 1 (depende de tus datos de prueba)
    e.nombre = 'Sentadilla' : limita al ejercicio específico
  ORDER BY ASC: muestra la progresión cronológica (de más antiguo a más reciente).

  Nota: esta consulta asume que el alumno con id_alumno = 1 y un
  ejercicio llamado exactamente 'Sentadilla' existen en tus datos
  de prueba. Si esos datos no están cargados, la consulta corre
  sin error pero devuelve cero filas.
*/
SELECT
    se.fecha,
    re.peso_utilizado              AS peso_kg,
    re.series_realizadas           AS series,
    re.repeticiones_realizadas     AS reps,
    re.rir_promedio                AS rir,
    ISNULL(re.observaciones, N'-') AS observaciones
FROM  dbo.REGISTRO_EJERCICIO     re
INNER JOIN dbo.RUTINA_EJERCICIO  rue ON rue.id_rutina_ejercicio = re.id_rutina_ejercicio
INNER JOIN dbo.EJERCICIO          e  ON e.id_ejercicio          = rue.id_ejercicio
INNER JOIN dbo.SESION_ENTRENAMIENTO se ON se.id_sesion          = re.id_sesion
WHERE  se.id_alumno = 1
  AND  e.nombre     = N'Sentadilla'
ORDER BY se.fecha ASC;
GO


-- ── Q10 ──────────────────────────────────────────────────────────────
/*
  Estadísticas de sugerencias agrupadas por nivel de alumno.

  Técnica principal: CASE dentro de SUM para pivoteo manual + NULLIF.
  Propósito         : Analiza si el comportamiento de las sugerencias
                      (aprobaciones, rechazos) varía según el nivel del alumno.
                      Permite ajustar la política de progresión por nivel.

  CASE dentro de SUM:
    SUM(CASE WHEN condición THEN 1 ELSE 0 END) es el patrón estándar
    para contar ocurrencias de un valor específico dentro de un GROUP BY,
    equivalente a un COUNTIF de Excel.
  pct_aprobacion:
    Incluye Aprobadas (2) y Aplicadas (4) en el numerador, ya que
    ambas representan sugerencias que el coach aceptó.

  Sin cambios: los id de ESTADO_SUGERENCIA (1 Pendiente, 2 Aprobada,
  3 Rechazada, 4 Aplicada) coinciden exactamente con la carga del DDL.
*/
SELECT
    na.nombre_nivel                                          AS nivel,
    COUNT(sp.id_sugerencia)                                 AS total_sugerencias,
    SUM(CASE WHEN sp.id_estado_sugerencia = 1 THEN 1 ELSE 0 END) AS pendientes,
    SUM(CASE WHEN sp.id_estado_sugerencia = 2 THEN 1 ELSE 0 END) AS aprobadas,
    SUM(CASE WHEN sp.id_estado_sugerencia = 3 THEN 1 ELSE 0 END) AS rechazadas,
    SUM(CASE WHEN sp.id_estado_sugerencia = 4 THEN 1 ELSE 0 END) AS aplicadas,
    CAST(
        100.0 * SUM(CASE WHEN sp.id_estado_sugerencia IN (2,4) THEN 1 ELSE 0 END)
              / NULLIF(COUNT(sp.id_sugerencia), 0)
        AS DECIMAL(5,2)
    )                                                       AS pct_aprobacion
FROM  dbo.SUGERENCIA_PROGRESION        sp
INNER JOIN dbo.RUTINA_EJERCICIO         re ON re.id_rutina_ejercicio    = sp.id_rutina_ejercicio
INNER JOIN dbo.RUTINA                   r  ON r.id_rutina               = re.id_rutina
INNER JOIN dbo.ALUMNO                   a  ON a.id_alumno               = r.id_alumno
INNER JOIN dbo.NIVEL_ALUMNO             na ON na.id_nivel_alumno        = a.id_nivel_alumno
GROUP BY na.id_nivel_alumno, na.nombre_nivel
ORDER BY na.id_nivel_alumno;
GO


-- ── Q11 ──────────────────────────────────────────────────────────────
/*
  Historial completo de progresiones con detalle de ejercicio
  y diferencia de peso.

  Técnica principal: JOIN múltiple (6 tablas) + columna calculada.
  Propósito         : Auditoría de todas las decisiones de progresión
                      resueltas. Muestra qué pasó con cada sugerencia:
                      si se aprobó/rechazó, cuándo, para qué ejercicio
                      y cuánto varió el peso.

  Cadena de JOINs:
    HISTORIAL → ACCION_PROGRESION      (nombre de la acción)
    HISTORIAL → SUGERENCIA_PROGRESION  (contexto de la sugerencia)
             → RUTINA_EJERCICIO        (prescripción afectada)
             → EJERCICIO               (nombre y grupo muscular)
             → RUTINA                  (para llegar al alumno)
             → ALUMNO + NIVEL_ALUMNO   (datos del alumno)

  diferencia_kg:
    Columna calculada en SELECT. Para rechazadas será 0 (peso_nuevo = peso_anterior).
    Para aprobadas/aplicadas mostrará el incremento real.
*/
SELECT
    h.id_historial,
    h.fecha_resolucion,
    ap.nombre_accion               AS accion,
    a.nombre + N' ' + a.apellido   AS alumno,
    na.nombre_nivel                AS nivel,
    e.nombre                       AS ejercicio,
    e.grupo_muscular,
    h.peso_anterior,
    h.peso_nuevo,
    h.peso_nuevo - h.peso_anterior AS diferencia_kg,
    ISNULL(h.observaciones, N'-')  AS observaciones
FROM  dbo.HISTORIAL_PROGRESION        h
INNER JOIN dbo.ACCION_PROGRESION       ap ON ap.id_accion_progresion   = h.id_accion_progresion
INNER JOIN dbo.SUGERENCIA_PROGRESION   sp ON sp.id_sugerencia          = h.id_sugerencia
INNER JOIN dbo.RUTINA_EJERCICIO        re ON re.id_rutina_ejercicio    = sp.id_rutina_ejercicio
INNER JOIN dbo.EJERCICIO               e  ON e.id_ejercicio            = re.id_ejercicio
INNER JOIN dbo.RUTINA                  r  ON r.id_rutina               = re.id_rutina
INNER JOIN dbo.ALUMNO                  a  ON a.id_alumno               = r.id_alumno
INNER JOIN dbo.NIVEL_ALUMNO            na ON na.id_nivel_alumno        = a.id_nivel_alumno
ORDER BY h.fecha_resolucion DESC, a.apellido;
GO


-- ── Q12 ──────────────────────────────────────────────────────────────
/*
  Ranking de alumnos por volumen acumulado total.

  Técnica principal: ROW_NUMBER() en subconsulta FROM (tabla derivada).
  Propósito         : Clasifica a los alumnos por volumen total levantado
                      en todas sus sesiones. Identifica a los más activos
                      y a los que necesitan mayor seguimiento.

  ROW_NUMBER() OVER (ORDER BY ...):
    Función de ventana que asigna un número secuencial a cada fila
    según el criterio de ordenamiento. A diferencia de RANK(),
    no deja huecos en caso de empate (asigna rangos consecutivos).

  Subconsulta derivada (tabla derivada en FROM):
    Se necesita porque ROW_NUMBER() no puede usarse directamente
    con expresiones de agregación (SUM/COUNT) en el mismo nivel SELECT.
    La subconsulta calcula las métricas primero, y luego la consulta
    exterior aplica la ventana de ranking sobre el resultado.

  LEFT JOIN con SESION y REGISTRO:
    Incluye alumnos sin sesiones o sin registros (volumen = 0 con ISNULL).
    Esto garantiza que todos los alumnos aparezcan en el ranking.
*/
SELECT
    ROW_NUMBER() OVER (ORDER BY sub.volumen_total DESC) AS ranking,
    sub.alumno,
    sub.nivel,
    sub.total_sesiones,
    sub.volumen_total                                   AS volumen_total_kg
FROM (
    SELECT
        a.nombre + N' ' + a.apellido   AS alumno,
        na.nombre_nivel                AS nivel,
        COUNT(DISTINCT se.id_sesion)   AS total_sesiones,
        ISNULL(SUM(
            CAST(re.series_realizadas       AS DECIMAL(12,2)) *
            CAST(re.repeticiones_realizadas AS DECIMAL(12,2)) *
            re.peso_utilizado
        ), 0)                          AS volumen_total
    FROM  dbo.ALUMNO              a
    INNER JOIN dbo.NIVEL_ALUMNO   na ON na.id_nivel_alumno  = a.id_nivel_alumno
    LEFT  JOIN dbo.SESION_ENTRENAMIENTO se ON se.id_alumno  = a.id_alumno
    LEFT  JOIN dbo.REGISTRO_EJERCICIO   re ON re.id_sesion  = se.id_sesion
    GROUP BY a.id_alumno, a.nombre, a.apellido, na.nombre_nivel
) sub
ORDER BY ranking;
GO
