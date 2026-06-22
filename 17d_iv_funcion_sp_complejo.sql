USE CoachesOnlineDB;
GO

/*
  Sección 17d (iv) – FUNCIÓN ESCALAR + SP COMPLEJO
  
  :
    1. FN_VolumenSesion (@id_sesion INT) → DECIMAL(12,2)
       Calcula el volumen total de carga de una sesión.

    2. SP_PanelCoach (@id_coach INT)
       SP complejo que devuelve 3 result sets con métricas
       del coach y sus alumnos. Usa FN_VolumenSesion internamente.

  DEPENDENCIA: FN_VolumenSesion debe crearse antes que SP_PanelCoach
               ya que el SP la llama en su tercer result set.
*/

-- Limpieza previa
IF OBJECT_ID('dbo.SP_PanelCoach', 'P')  IS NOT NULL DROP PROCEDURE dbo.SP_PanelCoach;
GO
IF OBJECT_ID('dbo.FN_VolumenSesion', 'FN') IS NOT NULL DROP FUNCTION  dbo.FN_VolumenSesion;
GO


-- FUNCIÓN ESCALAR – FN_VolumenSesion
/*
  Propósito:
    Calcula el volumen total de carga levantada en una sesión,
    definido como la suma de (series × repeticiones × peso) de todos
    los registros de ejercicio de esa sesión.

  Parámetro:
    @id_sesion INT: ID de la sesión a calcular

  Retorno:
    DECIMAL(12,2): volumen en kg. Retorna 0 si la sesión no
    tiene registros (sesiones canceladas o sin ejercicios aún).

  Uso del ISNULL:
    SUM() sobre un conjunto vacío retorna NULL en SQL Server.
    ISNULL(..., 0) convierte ese NULL en 0 para facilitar
    operaciones aritméticas downstream (ej: AVG en SP_PanelCoach).
*/

CREATE FUNCTION dbo.FN_VolumenSesion (@id_sesion INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @volumen DECIMAL(12,2);

    SELECT @volumen = ISNULL(
        SUM(
            CAST(re.series_realizadas       AS DECIMAL(12,2)) * -- CAST convierte los valores a decimal
            CAST(re.repeticiones_realizadas AS DECIMAL(12,2)) *
            re.peso_utilizado
        ), 0) -- se devuelve cero si la sesión no tiene registros de ejercicios
    FROM dbo.REGISTRO_EJERCICIO re
    WHERE re.id_sesion = @id_sesion;

    RETURN @volumen;
END;
GO



-- SP COMPLEJO: SP_PanelCoach

/*
  SP_PanelCoach
  
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
      - MAX(se.fecha) + DATEDIFF: detecta alumnos inactivos.
      - Subconsulta correlacionada: cuenta sugerencias pendientes
        navegando la cadena SUGERENCIA → RUTINA_EJERCICIO → RUTINA.
      - Ordenado por dias_sin_sesion DESC para que los más inactivos
        aparezcan primero (priorización de seguimiento).

    RS3 – Estadísticas de sesiones con volumen:
      Agrupa sesiones de todos los alumnos del coach por estado
      (Completa / Parcial / Cancelada) y calcula:
        - total_sesiones
        - volumen_total_kg  (SUM de FN_VolumenSesion)
        - volumen_promedio_kg (AVG de FN_VolumenSesion)
      Para evitar llamar FN_VolumenSesion dos veces por fila
      (una para SUM, otra para AVG), se pre-calcula el volumen
      en una subconsulta derivada antes de agregar.

  Parámetro:
    @id_coach INT : ID del coach a consultar

*/

CREATE PROCEDURE dbo.SP_PanelCoach
    @id_coach INT
AS
BEGIN
    SET NOCOUNT ON; -- NOCOUNT es para que el programa no tire mensaje de "x filas afectadas"

    -- Valido que el coach exista
    IF NOT EXISTS (SELECT 1 FROM dbo.COACH WHERE id_coach = @id_coach)
    BEGIN
        RAISERROR('Coach no encontrado.', 16, 1);
        RETURN;
    END;

    -- Resultado 1: Ficha del coach + total de alumnos activos 
    SELECT
        c.id_coach,
        c.nombre + N' ' + c.apellido    AS coach,
        c.email,
        c.especialidad,
        ec.nombre_estado                AS estado_coach, 
        COUNT(a.id_alumno)              AS total_alumnos_activos -- COUNT() nos devuelve cuántos alumnos tiene el coach
    FROM  dbo.COACH         c
    INNER JOIN dbo.ESTADO_COACH ec ON ec.id_estado_coach  = c.id_estado_coach -- ese INNER JOIN sirve para mostrar el nombre del estado
    LEFT  JOIN dbo.ALUMNO       a  ON a.id_coach           = c.id_coach -- ese LEFT JOIN es para mostrar al coach aunque no tenga alumnos activos.
                                  AND a.id_estado_alumno   = 1 -- solo alumnos activos
    WHERE  c.id_coach = @id_coach -- solo este coach
    GROUP BY c.id_coach, c.nombre, c.apellido, c.email, c.especialidad, ec.nombre_estado; --agrupa según datos del coach

     -- Resultado 2: Alumnos activos para el coach especifico y sus días sin tener sesión
    SELECT
        a.id_alumno,
        a.nombre + N' ' + a.apellido    AS alumno,
        na.nombre_nivel                 AS nivel,
        ISNULL(oe.nombre_objetivo, N'Sin objetivo') AS objetivo,
        -- Sugerencias pendientes del alumno (subconsulta correlacionada) --> todo ese caminito es para conectar sugerencia con alumno
        (
            SELECT COUNT(sp2.id_sugerencia) -- cantidad de sugerencias
            FROM   dbo.SUGERENCIA_PROGRESION sp2
            INNER JOIN dbo.RUTINA_EJERCICIO  re2 ON re2.id_rutina_ejercicio = sp2.id_rutina_ejercicio
            INNER JOIN dbo.RUTINA            ru2 ON ru2.id_rutina           = re2.id_rutina
            WHERE  ru2.id_alumno             = a.id_alumno -- contame la cantidad de sugerencias cuando el id de alumno sea sobre el que se está iterando
              AND  sp2.id_estado_sugerencia  = 1 -- sugerencias en estado pendiente
        )                               AS sugerencias_pendientes,
        MAX(se.fecha)                   AS ultima_sesion,
        DATEDIFF(DAY, MAX(se.fecha), GETDATE()) AS dias_sin_sesion
    FROM  dbo.ALUMNO                    a
    INNER JOIN dbo.NIVEL_ALUMNO         na ON na.id_nivel_alumno          = a.id_nivel_alumno
    LEFT  JOIN dbo.OBJETIVO_ENTRENAMIENTO oe ON oe.id_objetivo_entrenamiento  = a.id_objetivo_entrenamiento -- puede no tener objetivo y estar activo
    LEFT  JOIN dbo.SESION_ENTRENAMIENTO se ON se.id_alumno                = a.id_alumno -- puede no tener sesiones pero estar activo
    WHERE  a.id_coach         = @id_coach
      AND  a.id_estado_alumno = 1 -- estado activo
    GROUP BY a.id_alumno, a.nombre, a.apellido, na.nombre_nivel, oe.nombre_objetivo
    ORDER BY dias_sin_sesion DESC;

    -- Resultado 3: Estadísticas de sesiones por estado con volumen
    -- Precalcular volumen una vez por sesión para no llamar la función dos veces en la misma fila (evita doble costo por fila en SUM + AVG)
    SELECT
        es.nombre_estado                AS estado_sesion,
        COUNT(v.id_sesion)              AS total_sesiones,
        SUM(v.volumen)                  AS volumen_total_kg,
        CAST(AVG(v.volumen) AS DECIMAL(10,2)) AS volumen_promedio_kg
    FROM (
        SELECT
            se.id_sesion,
            se.id_estado_sesion,
            dbo.FN_VolumenSesion(se.id_sesion) AS volumen  -- una llamada por sesión
        FROM  dbo.SESION_ENTRENAMIENTO se
        INNER JOIN dbo.ALUMNO          a  ON a.id_alumno  = se.id_alumno -- la idea es conectar coach con todas sesiones
        WHERE  a.id_coach = @id_coach
    ) v
    INNER JOIN dbo.ESTADO_SESION es ON es.id_estado_sesion = v.id_estado_sesion -- traducir el estado de sesión (de id (1,2,3) a nombre de estado(completa, etc))
    GROUP BY es.nombre_estado -- agrupa por estado, no por alumno
    ORDER BY total_sesiones DESC; 
END;
GO


-- A modo de ejemplo:

EXEC dbo.SP_PanelCoach 1;

