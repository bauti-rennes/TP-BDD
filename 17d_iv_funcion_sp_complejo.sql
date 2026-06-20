USE CoachesOnlineDB;
GO

/*
=============================================================
  SECCIÓN 17d (iv) – FUNCIÓN ESCALAR + SP COMPLEJO
  TP Integrador – Ingeniería de Datos I – UADE
  Docente: Ing. Franco Salazar

  Objetos definidos:
    1. FN_VolumenSesion (@id_sesion INT) → DECIMAL(12,2)
       Calcula el volumen total de carga de una sesión.

    2. SP_PanelCoach (@id_coach INT)
       SP complejo que devuelve 3 result sets con métricas
       del coach y sus alumnos. Usa FN_VolumenSesion internamente.

  DEPENDENCIA: FN_VolumenSesion debe crearse antes que SP_PanelCoach
               ya que el SP la llama en su tercer result set.
=============================================================
*/

-- Limpieza previa
IF OBJECT_ID('dbo.SP_PanelCoach',      'P')  IS NOT NULL DROP PROCEDURE dbo.SP_PanelCoach;
GO
IF OBJECT_ID('dbo.FN_VolumenSesion',   'FN') IS NOT NULL DROP FUNCTION  dbo.FN_VolumenSesion;
GO


-- ============================================================
-- FUNCIÓN ESCALAR – FN_VolumenSesion
-- ============================================================
/*
  FN_VolumenSesion
  ─────────────────
  Propósito:
    Calcula el volumen total de carga levantada en una sesión,
    definido como la suma de (series × repeticiones × peso) de todos
    los registros de ejercicio de esa sesión.

    Volumen = Σ (series_realizadas × repeticiones_realizadas × peso_utilizado)

  Parámetro:
    @id_sesion INT : ID de la sesión a calcular

  Retorno:
    DECIMAL(12,2) : volumen en kg. Retorna 0 si la sesión no
    tiene registros (sesiones canceladas o sin ejercicios aún).

  Uso del ISNULL:
    SUM() sobre un conjunto vacío retorna NULL en SQL Server.
    ISNULL(..., 0) convierte ese NULL en 0 para facilitar
    operaciones aritméticas downstream (ej.: AVG en SP_PanelCoach).

  Uso típico:
    SELECT dbo.FN_VolumenSesion(3) AS volumen;   -- resultado: 4800 kg
    SELECT dbo.FN_VolumenSesion(12) AS volumen;  -- resultado: 0 (cancelada)

  Nota sobre rendimiento:
    Las funciones escalares en SQL Server se evalúan fila a fila.
    Para consultas masivas conviene pre-calcular los volúmenes
    en una subconsulta/CTE y usar la función una sola vez por sesión
    (ver implementación de RS3 en SP_PanelCoach).
*/
CREATE FUNCTION dbo.FN_VolumenSesion (@id_sesion INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @volumen DECIMAL(12,2);

    SELECT @volumen = ISNULL(
        SUM(
            CAST(re.series_realizadas       AS DECIMAL(12,2)) *
            CAST(re.repeticiones_realizadas AS DECIMAL(12,2)) *
            re.peso_utilizado
        ), 0)
    FROM dbo.REGISTRO_EJERCICIO re
    WHERE re.id_sesion = @id_sesion;

    RETURN @volumen;
END;
GO


-- ============================================================
-- SP COMPLEJO – SP_PanelCoach
-- ============================================================
/*
  SP_PanelCoach
  ──────────────
  Propósito:
    Panel de métricas operativas de un coach. Devuelve 3 result sets
    en una sola ejecución, diseñados para alimentar un dashboard:

    RS1 – Ficha del coach:
      Datos del coach + cantidad total de alumnos activos asignados.
      JOIN LEFT con ALUMNO para que el conteo sea 0 si no tiene alumnos
      (COUNT sobre LEFT JOIN retorna 0 en vez de NULL).

    RS2 – Estado de sus alumnos activos:
      Para cada alumno activo lista: nivel, objetivo, última sesión,
      días sin actividad y cantidad de sugerencias pendientes.
      · MAX(se.fecha) + DATEDIFF: detecta alumnos inactivos.
      · Subconsulta correlacionada: cuenta sugerencias pendientes
        navegando la cadena SUGERENCIA → RUTINA_EJERCICIO → RUTINA.
      · Ordenado por dias_sin_sesion DESC para que los más inactivos
        aparezcan primero (priorización de seguimiento).

    RS3 – Estadísticas de sesiones con volumen:
      Agrupa sesiones de todos los alumnos del coach por estado
      (Completa / Parcial / Cancelada) y calcula:
        · total_sesiones
        · volumen_total_kg  (SUM de FN_VolumenSesion)
        · volumen_promedio_kg (AVG de FN_VolumenSesion)
      Para evitar llamar FN_VolumenSesion dos veces por fila
      (una para SUM, otra para AVG), se pre-calcula el volumen
      en una subconsulta derivada antes de agregar.

  Parámetro:
    @id_coach INT : ID del coach a consultar

  Ejemplo de uso:
    EXEC dbo.SP_PanelCoach @id_coach = 1;  -- Panel de Ana García
    EXEC dbo.SP_PanelCoach @id_coach = 8;  -- Panel de Pablo González
*/
CREATE PROCEDURE dbo.SP_PanelCoach
    @id_coach INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validación inicial: el coach debe existir
    IF NOT EXISTS (SELECT 1 FROM dbo.COACH WHERE id_coach = @id_coach)
    BEGIN
        RAISERROR('Coach no encontrado.', 16, 1);
        RETURN;
    END;

    /* ── RS1: Ficha del coach + total de alumnos activos ─────────── */
    SELECT
        c.id_coach,
        c.nombre + N' ' + c.apellido    AS coach,
        c.email,
        c.especialidad,
        ec.nombre_estado                AS estado_coach,
        COUNT(a.id_alumno)              AS total_alumnos_activos
    FROM  dbo.COACH         c
    INNER JOIN dbo.ESTADO_COACH ec ON ec.id_estado_coach  = c.id_estado_coach
    LEFT  JOIN dbo.ALUMNO       a  ON a.id_coach           = c.id_coach
                                  AND a.id_estado_alumno   = 1
    WHERE  c.id_coach = @id_coach
    GROUP BY c.id_coach, c.nombre, c.apellido, c.email, c.especialidad, ec.nombre_estado;

    /* ── RS2: Alumnos activos con actividad reciente ──────────────── */
    SELECT
        a.id_alumno,
        a.nombre + N' ' + a.apellido    AS alumno,
        na.nombre_nivel                 AS nivel,
        ISNULL(oe.nombre_objetivo, N'Sin objetivo') AS objetivo,
        -- Sugerencias pendientes del alumno (subconsulta correlacionada)
        (
            SELECT COUNT(*)
            FROM   dbo.SUGERENCIA_PROGRESION sp2
            INNER JOIN dbo.RUTINA_EJERCICIO  re2 ON re2.id_rutina_ejercicio = sp2.id_rutina_ejercicio
            INNER JOIN dbo.RUTINA            ru2 ON ru2.id_rutina           = re2.id_rutina
            WHERE  ru2.id_alumno             = a.id_alumno
              AND  sp2.id_estado_sugerencia  = 1
        )                               AS sugerencias_pendientes,
        MAX(se.fecha)                   AS ultima_sesion,
        DATEDIFF(DAY, MAX(se.fecha), GETDATE()) AS dias_sin_sesion
    FROM  dbo.ALUMNO                    a
    INNER JOIN dbo.NIVEL_ALUMNO         na ON na.id_nivel_alumno          = a.id_nivel_alumno
    LEFT  JOIN dbo.OBJETIVO_ENTRENAMIENTO oe
                                        ON oe.id_objetivo_entrenamiento  = a.id_objetivo_entrenamiento
    LEFT  JOIN dbo.SESION_ENTRENAMIENTO se ON se.id_alumno                = a.id_alumno
    WHERE  a.id_coach         = @id_coach
      AND  a.id_estado_alumno = 1
    GROUP BY a.id_alumno, a.nombre, a.apellido, na.nombre_nivel, oe.nombre_objetivo
    ORDER BY dias_sin_sesion DESC;

    /* ── RS3: Estadísticas de sesiones por estado con volumen ────── */
    -- Pre-calcular volumen una vez por sesión para no llamar la función
    -- dos veces en la misma fila (evita doble costo por fila en SUM + AVG)
    SELECT
        es.nombre_estado                AS estado_sesion,
        COUNT(*)                        AS total_sesiones,
        SUM(v.volumen)                  AS volumen_total_kg,
        CAST(AVG(v.volumen) AS DECIMAL(10,2)) AS volumen_promedio_kg
    FROM (
        SELECT
            se.id_sesion,
            se.id_estado_sesion,
            dbo.FN_VolumenSesion(se.id_sesion) AS volumen  -- una llamada por sesión
        FROM  dbo.SESION_ENTRENAMIENTO se
        INNER JOIN dbo.ALUMNO          a  ON a.id_alumno  = se.id_alumno
        WHERE  a.id_coach = @id_coach
    ) v
    INNER JOIN dbo.ESTADO_SESION es ON es.id_estado_sesion = v.id_estado_sesion
    GROUP BY es.nombre_estado
    ORDER BY total_sesiones DESC;
END;
GO
