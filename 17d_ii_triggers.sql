USE CoachesOnlineDB;
GO

/*
=============================================================
  SECCIÓN 17d (ii) – TRIGGERS
  TP Integrador – Ingeniería de Datos I – UADE
  Docente: Ing. Franco Salazar

  IMPORTANTE: Ejecutar este script DESPUÉS de 17c_datos_prueba.sql.
  Los triggers no deben dispararse durante las inserciones
  de prueba, ya que algunas condiciones del dataset histórico
  (ej.: sug9 y sug10 insertadas directamente como Aplicadas)
  no pasan por el flujo de UPDATE que activa el trigger 2.

  Triggers definidos:
    1. TR_ValidarAlumnoActivoEnSesion
       Tabla  : SESION_ENTRENAMIENTO
       Evento : AFTER INSERT
       Propósito: rechaza sesiones para alumnos no Activos

    2. TR_AplicarProgresionAlResolver
       Tabla  : SUGERENCIA_PROGRESION
       Evento : AFTER UPDATE
       Propósito: sincroniza RUTINA_EJERCICIO.peso_sugerido
                  cuando una sugerencia pasa a estado Aplicada (4)

    3. TR_GenerarSugerenciaProgresion
       Tabla  : REGISTRO_EJERCICIO
       Evento : AFTER INSERT
       Propósito: genera automáticamente una sugerencia de progresión
                  cuando el alumno cumple el objetivo con RIR de sobra,
                  usando NIVEL_ALUMNO.porcentaje_incremento_base
=============================================================
*/

-- Limpieza previa
IF OBJECT_ID('dbo.TR_GenerarSugerenciaProgresion', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_GenerarSugerenciaProgresion;
GO
IF OBJECT_ID('dbo.TR_AplicarProgresionAlResolver', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_AplicarProgresionAlResolver;
GO
IF OBJECT_ID('dbo.TR_ValidarAlumnoActivoEnSesion', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_ValidarAlumnoActivoEnSesion;
GO


-- ============================================================
-- TRIGGER 1 – Validación de alumno activo al crear sesión
-- ============================================================
/*
  TR_ValidarAlumnoActivoEnSesion
  ────────────────────────────────
  Dispara AFTER INSERT en SESION_ENTRENAMIENTO.

  Regla de negocio:
    Solo un alumno con estado Activo (id_estado_alumno = 1) puede
    tener sesiones registradas. Un alumno en estado Pausado o Baja
    no debe generar actividad de entrenamiento.

  Implementación:
    Hace JOIN entre la tabla virtual "inserted" (filas recién insertadas)
    y ALUMNO para verificar el estado. Si alguna de las filas insertadas
    corresponde a un alumno no activo, se hace ROLLBACK de toda la
    transacción y se lanza un error descriptivo.

  Consideración de batch:
    La consulta EXISTS sobre "inserted" cubre inserción de múltiples
    filas simultáneas, no solo fila a fila. Esto es necesario porque
    SQL Server ejecuta el trigger una sola vez por sentencia INSERT,
    con todas las filas en "inserted".

  Ejemplo de uso:
    -- Primero poner al alumno en estado Baja (3)
    EXEC dbo.SP_UpdateEstadoAlumno @id_alumno = 3, @id_estado_alumno = 3;
    -- Este INSERT fallará con el mensaje del trigger:
    EXEC dbo.SP_InsertSesionEntrenamiento @id_alumno = 3, @fecha = '2025-07-01';
*/
CREATE TRIGGER dbo.TR_ValidarAlumnoActivoEnSesion
ON  dbo.SESION_ENTRENAMIENTO
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verifica si alguna fila insertada referencia un alumno no activo
    IF EXISTS (
        SELECT 1
        FROM   inserted i
        INNER JOIN dbo.ALUMNO a ON a.id_alumno = i.id_alumno
        WHERE  a.id_estado_alumno <> 1   -- 1 = Activo
    )
    BEGIN
        -- ROLLBACK cancela la inserción completa (todas las filas del batch)
        ROLLBACK TRANSACTION;
        RAISERROR(
            'No se puede registrar una sesión para un alumno que no está Activo.',
            16, 1
        );
    END;
END;
GO


-- ============================================================
-- TRIGGER 2 – Aplicación automática de progresión aprobada
-- ============================================================
/*
  TR_AplicarProgresionAlResolver
  ────────────────────────────────
  Dispara AFTER UPDATE en SUGERENCIA_PROGRESION.

  Regla de negocio:
    Cuando el coach cambia el estado de una sugerencia a Aplicada (4),
    el peso sugerido de la prescripción (RUTINA_EJERCICIO) debe
    actualizarse automáticamente con el peso aprobado en la sugerencia.
    Esto mantiene la sincronía sin requerir una segunda operación manual.

  Implementación:
    a) IF NOT UPDATE(id_estado_sugerencia) RETURN:
       Salida inmediata si la columna de estado no fue tocada en el UPDATE.
       Optimización que evita trabajo innecesario para updates de otros campos
       (ej.: corrección del motivo).

    b) JOIN inserted / deleted:
       - "inserted" contiene el estado NUEVO de las filas modificadas.
       - "deleted"  contiene el estado ANTERIOR de las mismas filas.
       Se filtran solo las filas donde:
         * nuevo estado = 4 (Aplicada)
         * estado anterior ≠ 4 (para evitar re-aplicación si se actualiza
           otra columna con la sugerencia ya Aplicada)

    c) Actualización set-based:
       Opera sobre todas las filas afectadas de una vez, sin cursores.
       Compatible con actualizaciones de múltiples sugerencias en lote.

  Ejemplo de uso:
    -- Resuelve la sugerencia 7 (Pendiente → Aplicada).
    -- El trigger actualizará re4.peso_sugerido de 70.00 a 75.00 automáticamente.
    EXEC dbo.SP_ResolverSugerenciaProgresion @id_sugerencia = 7, @id_estado_sugerencia = 4;
    -- Verificar resultado:
    SELECT peso_sugerido FROM dbo.RUTINA_EJERCICIO WHERE id_rutina_ejercicio = 4;
*/
CREATE TRIGGER dbo.TR_AplicarProgresionAlResolver
ON  dbo.SUGERENCIA_PROGRESION
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Optimización: si la columna de estado no cambió, no hay nada que sincronizar
    IF NOT UPDATE(id_estado_sugerencia) RETURN;

    -- Actualiza el peso en RUTINA_EJERCICIO para las sugerencias
    -- que pasaron de cualquier estado a Aplicada (4)
    UPDATE re
    SET    re.peso_sugerido = i.peso_sugerido
    FROM   dbo.RUTINA_EJERCICIO      re
    INNER JOIN inserted              i  ON i.id_rutina_ejercicio = re.id_rutina_ejercicio
    INNER JOIN deleted               d  ON d.id_sugerencia       = i.id_sugerencia
    WHERE  i.id_estado_sugerencia = 4    -- estado nuevo = Aplicada
      AND  d.id_estado_sugerencia <> 4;  -- estado anterior ≠ Aplicada (evita re-aplicación)
END;
GO


-- ============================================================
-- TRIGGER 3 – Generación automática de sugerencia de progresión
-- ============================================================
/*
  TR_GenerarSugerenciaProgresion
  ────────────────────────────────
  Dispara AFTER INSERT en REGISTRO_EJERCICIO.

  Regla de negocio (autorregulación por RIR):
    Cuando un alumno registra un ejercicio y:
      a) cumple o supera las series objetivo,
      b) cumple o supera las repeticiones objetivo, y
      c) termina con un RIR igual o mayor al objetivo
         (le sobró esfuerzo, el peso le resultó manejable),
    el sistema interpreta que está listo para progresar y genera
    automáticamente una SUGERENCIA_PROGRESION en estado Pendiente (1).

    El incremento se calcula con el porcentaje propio del NIVEL del
    alumno (NIVEL_ALUMNO.porcentaje_incremento_base):
      peso_nuevo = peso_sugerido_actual × (1 + porcentaje / 100)
    Así un Novato progresa más rápido (7.50%) que un Avanzado (2.50%).

  Implementación:
    a) CTE "candidatas": navega la cadena
       REGISTRO → RUTINA_EJERCICIO → RUTINA → ALUMNO → NIVEL_ALUMNO
       para obtener el porcentaje del nivel y calcular el peso nuevo.
       ROW_NUMBER asegura una sola sugerencia por prescripción aunque
       el INSERT traiga varias filas (set-based, sin cursores).

    b) Filtros de inserción:
       · peso_nuevo > peso_actual  → evita sugerencias triviales y
         respeta el CHECK CK_SUGERENCIA_incremento_real.
       · NOT EXISTS sugerencia Pendiente → respeta el índice filtrado
         UX_SUGERENCIA_pendiente_por_prescripcion (una Pendiente por
         prescripción) y evita la excepción de índice único.

  Nota:
    Este trigger NO debe dispararse durante la carga de datos de
    prueba (17c). Por eso este script se ejecuta DESPUÉS de 17c.

  Ejemplo de uso:
    -- Suponiendo re5 con series_objetivo=3, repeticiones_objetivo=10,
    -- rir_objetivo=2 y peso_sugerido=60.00, para un alumno Intermedio (5%):
    EXEC dbo.SP_InsertRegistroEjercicio
         @id_sesion = 1, @id_rutina_ejercicio = 5,
         @series_realizadas = 3, @repeticiones_realizadas = 10,
         @peso_utilizado = 60.00, @rir_promedio = 3;
    -- Se generará una sugerencia Pendiente: 60.00 → 63.00 (5%).
*/
CREATE TRIGGER dbo.TR_GenerarSugerenciaProgresion
ON  dbo.REGISTRO_EJERCICIO
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH candidatas AS (
        SELECT
            re.id_rutina_ejercicio,
            re.peso_sugerido                              AS peso_actual,
            na.porcentaje_incremento_base                 AS porcentaje,
            CAST(re.peso_sugerido * (1 + na.porcentaje_incremento_base / 100.0)
                 AS DECIMAL(6,2))                         AS peso_nuevo,
            ROW_NUMBER() OVER (
                PARTITION BY re.id_rutina_ejercicio
                ORDER BY i.id_registro DESC
            )                                             AS rn
        FROM   inserted i
        INNER JOIN dbo.RUTINA_EJERCICIO re ON re.id_rutina_ejercicio = i.id_rutina_ejercicio
        INNER JOIN dbo.RUTINA           ru ON ru.id_rutina           = re.id_rutina
        INNER JOIN dbo.ALUMNO           a  ON a.id_alumno            = ru.id_alumno
        INNER JOIN dbo.NIVEL_ALUMNO     na ON na.id_nivel_alumno     = a.id_nivel_alumno
        WHERE  i.series_realizadas       >= re.series_objetivo
          AND  i.repeticiones_realizadas >= re.repeticiones_objetivo
          AND  i.rir_promedio            >= re.rir_objetivo
          AND  re.peso_sugerido > 0
    )
    INSERT INTO dbo.SUGERENCIA_PROGRESION
        (id_rutina_ejercicio, id_estado_sugerencia, fecha_sugerencia,
         peso_actual, peso_sugerido, porcentaje_incremento, motivo)
    SELECT
        c.id_rutina_ejercicio,
        1,                              -- Pendiente
        CAST(GETDATE() AS DATE),
        c.peso_actual,
        c.peso_nuevo,
        c.porcentaje,
        N'Sugerencia automática: objetivo de series y repeticiones cumplido '
      + N'con RIR igual o mayor al objetivo. Incremento aplicado según el '
      + N'nivel del alumno.'
    FROM   candidatas c
    WHERE  c.rn = 1
      AND  c.peso_nuevo > c.peso_actual
      AND  NOT EXISTS (
            SELECT 1
            FROM   dbo.SUGERENCIA_PROGRESION sp
            WHERE  sp.id_rutina_ejercicio  = c.id_rutina_ejercicio
              AND  sp.id_estado_sugerencia = 1   -- ya hay una Pendiente
      );
END;
GO
