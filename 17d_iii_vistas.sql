USE CoachesOnlineDB;
GO

/*
=============================================================
  SECCIÓN 17d (iii) – VISTAS
  TP Integrador – Ingeniería de Datos I – UADE
  Docente: Ing. Franco Salazar

  Vistas definidas:
    1. VW_ResumenAlumno
       Panorama completo de cada alumno: estado, nivel,
       objetivo, coach y rutina activa (si tiene).

    2. VW_SugerenciasPendientes
       Todas las sugerencias en estado Pendiente con contexto
       completo: alumno, nivel, coach, rutina, ejercicio,
       pesos y motivo.
=============================================================
*/

-- Limpieza previa
IF OBJECT_ID('dbo.VW_SugerenciasPendientes', 'V') IS NOT NULL
    DROP VIEW dbo.VW_SugerenciasPendientes;
GO
IF OBJECT_ID('dbo.VW_ResumenAlumno', 'V') IS NOT NULL
    DROP VIEW dbo.VW_ResumenAlumno;
GO


-- ============================================================
-- VISTA 1 – Resumen completo del alumno
-- ============================================================
/*
  VW_ResumenAlumno
  ─────────────────
  Propósito:
    Proporciona una vista desnormalizada del alumno con toda
    la información necesaria para una pantalla de listado general,
    evitando que las capas superiores (aplicación, reportes)
    tengan que hacer JOINs repetidos.

  Tablas involucradas:
    ALUMNO → ESTADO_ALUMNO, NIVEL_ALUMNO, OBJETIVO_ENTRENAMIENTO,
    COACH, RUTINA (left join para capturar alumnos sin rutina activa)

  Consideración de diseño:
    El JOIN con RUTINA es LEFT JOIN filtrado por id_estado_rutina = 1.
    Esto hace que alumnos sin rutina activa igual aparezcan en la vista
    (con NULL en los campos de rutina), a diferencia de un INNER JOIN
    que los excluiría.
    El índice filtrado UX_RUTINA_activa_por_alumno garantiza
    que el LEFT JOIN devuelva como máximo una fila por alumno.

  Ejemplo de uso:
    SELECT * FROM dbo.VW_ResumenAlumno WHERE estado_alumno = 'Activo';
    SELECT * FROM dbo.VW_ResumenAlumno WHERE nivel = 'Avanzado' ORDER BY alumno;
*/
CREATE VIEW dbo.VW_ResumenAlumno
AS
SELECT
    a.id_alumno,
    a.nombre + N' ' + a.apellido                   AS alumno,
    a.email                                         AS email_alumno,
    a.fecha_alta,
    ea.nombre_estado                                AS estado_alumno,
    na.nombre_nivel                                 AS nivel,
    na.porcentaje_incremento_base                   AS pct_incremento_base,
    ISNULL(oe.nombre_objetivo, N'Sin objetivo')     AS objetivo,
    c.id_coach,
    c.nombre + N' ' + c.apellido                   AS coach,
    c.especialidad                                  AS especialidad_coach,
    -- Rutina activa (NULL si el alumno no tiene rutina activa)
    r.id_rutina                                     AS id_rutina_activa,
    r.nombre                                        AS nombre_rutina_activa,
    r.fecha_inicio                                  AS inicio_rutina,
    r.id_objetivo_entrenamiento                     AS id_objetivo_rutina
FROM  dbo.ALUMNO                   a
INNER JOIN dbo.ESTADO_ALUMNO       ea ON ea.id_estado_alumno          = a.id_estado_alumno
INNER JOIN dbo.NIVEL_ALUMNO        na ON na.id_nivel_alumno           = a.id_nivel_alumno
LEFT  JOIN dbo.OBJETIVO_ENTRENAMIENTO oe
                                   ON oe.id_objetivo_entrenamiento    = a.id_objetivo_entrenamiento
INNER JOIN dbo.COACH               c  ON c.id_coach                  = a.id_coach
-- LEFT JOIN: incluye alumnos aunque no tengan rutina activa
LEFT  JOIN dbo.RUTINA              r  ON r.id_alumno                 = a.id_alumno
                                     AND r.id_estado_rutina          = 1;
GO


-- ============================================================
-- VISTA 2 – Sugerencias de progresión pendientes de revisión
-- ============================================================
/*
  VW_SugerenciasPendientes
  ─────────────────────────
  Propósito:
    Centraliza en una sola vista toda la información que el coach
    necesita para tomar una decisión sobre cada sugerencia pendiente:
    quién es el alumno, a qué nivel pertenece, qué ejercicio es,
    cuál es la prescripción actual (series/reps/rir) y qué cambio
    se propone (peso_actual → peso_sugerido con porcentaje).

  Tablas involucradas (cadena de JOINs de 7 tablas):
    SUGERENCIA_PROGRESION
      → RUTINA_EJERCICIO
        → EJERCICIO
        → RUTINA
          → ALUMNO
            → NIVEL_ALUMNO
            → COACH
          → OBJETIVO_ENTRENAMIENTO (left join: rutina puede no tener objetivo)

  Filtro:
    WHERE id_estado_sugerencia = 1 (solo Pendientes)
    Esta condición también coincide con el índice filtrado
    UX_SUGERENCIA_pendiente_por_prescripcion, lo que hace la
    consulta más eficiente al leerla directamente.

  Ejemplo de uso:
    -- Panel del coach 1 (Ana García)
    SELECT * FROM dbo.VW_SugerenciasPendientes WHERE coach LIKE 'Ana%';
    -- Sugerencias de alumnos Avanzados
    SELECT * FROM dbo.VW_SugerenciasPendientes WHERE nivel_alumno = 'Avanzado';
*/
CREATE VIEW dbo.VW_SugerenciasPendientes
AS
SELECT
    sp.id_sugerencia,
    sp.fecha_sugerencia,
    a.id_alumno,
    a.nombre + N' ' + a.apellido    AS alumno,
    na.nombre_nivel                 AS nivel_alumno,
    na.porcentaje_incremento_base   AS pct_incremento_base,
    c.nombre + N' ' + c.apellido    AS coach,
    r.id_rutina,
    r.nombre                        AS rutina,
    ISNULL(oe.nombre_objetivo, N'Sin objetivo') AS objetivo_rutina,
    e.nombre                        AS ejercicio,
    e.grupo_muscular,
    -- Prescripción actual
    re.series_objetivo,
    re.repeticiones_objetivo,
    re.rir_objetivo,
    -- Propuesta de progresión
    sp.peso_actual,
    sp.peso_sugerido,
    sp.porcentaje_incremento,
    sp.motivo
FROM  dbo.SUGERENCIA_PROGRESION         sp
INNER JOIN dbo.RUTINA_EJERCICIO          re ON re.id_rutina_ejercicio       = sp.id_rutina_ejercicio
INNER JOIN dbo.EJERCICIO                 e  ON e.id_ejercicio               = re.id_ejercicio
INNER JOIN dbo.RUTINA                    r  ON r.id_rutina                  = re.id_rutina
INNER JOIN dbo.ALUMNO                    a  ON a.id_alumno                  = r.id_alumno
INNER JOIN dbo.NIVEL_ALUMNO              na ON na.id_nivel_alumno           = a.id_nivel_alumno
INNER JOIN dbo.COACH                     c  ON c.id_coach                   = a.id_coach
LEFT  JOIN dbo.OBJETIVO_ENTRENAMIENTO    oe ON oe.id_objetivo_entrenamiento = r.id_objetivo_entrenamiento
WHERE  sp.id_estado_sugerencia = 1;  -- solo sugerencias Pendientes
GO
