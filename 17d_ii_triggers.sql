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
=============================================================
*/

-- Limpieza previa
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
