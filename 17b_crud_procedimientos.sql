USE CoachesOnlineDB;
GO

/*
=============================================================
  SECCIÓN 17b – PROCEDIMIENTOS ALMACENADOS CRUD
  TP Integrador – Ingeniería de Datos I – UADE
  Docente: Ing. Franco Salazar

  Se definen 2 procedimientos CRUD por tabla (22 en total).
  Tablas cubiertas:
    1.  OBJETIVO_ENTRENAMIENTO
    2.  NIVEL_ALUMNO
    3.  COACH
    4.  ALUMNO
    5.  RUTINA
    6.  EJERCICIO
    7.  RUTINA_EJERCICIO
    8.  SESION_ENTRENAMIENTO
    9.  REGISTRO_EJERCICIO
   10.  SUGERENCIA_PROGRESION
   11.  HISTORIAL_PROGRESION

  Convenciones:
    - SP_Insert<Tabla>  : alta con validaciones de negocio
    - SP_Update<Tabla>  : modificación parcial con patrón ISNULL
    - SP_Delete<Tabla>  : eliminación física (cuando aplica)
    - SP_Read<Tabla>    : consulta con filtro opcional
    - SP_Resolver<Tabla>: cambio de estado con reglas de negocio

  Cada SP usa SET NOCOUNT ON para evitar mensajes de filas
  afectadas que interfieran con la lectura de result sets.
=============================================================
*/

-- ============================================================
-- LIMPIEZA PREVIA
-- ============================================================
DECLARE @sp NVARCHAR(200);
DECLARE cur CURSOR FOR
SELECT name FROM sys.objects
WHERE  type = 'P' AND name IN (
    'SP_InsertObjetivoEntrenamiento', 'SP_ReadObjetivoEntrenamiento',
    'SP_InsertNivelAlumno',          'SP_UpdateNivelAlumno',
    'SP_InsertCoach',                'SP_UpdateCoach',
    'SP_InsertAlumno',               'SP_UpdateEstadoAlumno',
    'SP_InsertRutina',               'SP_UpdateRutina',
    'SP_InsertEjercicio',            'SP_UpdateEjercicio',
    'SP_InsertRutinaEjercicio',      'SP_UpdatePesoSugeridoRutinaEjercicio',
    'SP_InsertSesionEntrenamiento',  'SP_UpdateEstadoSesion',
    'SP_InsertRegistroEjercicio',    'SP_DeleteRegistroEjercicio',
    'SP_InsertSugerenciaProgresion', 'SP_ResolverSugerenciaProgresion',
    'SP_InsertHistorialProgresion',  'SP_ReadHistorialByAlumno'
);
OPEN cur;
FETCH NEXT FROM cur INTO @sp;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC ('DROP PROCEDURE dbo.' + @sp);
    FETCH NEXT FROM cur INTO @sp;
END;
CLOSE cur; DEALLOCATE cur;
GO


-- ============================================================
-- 1. OBJETIVO_ENTRENAMIENTO
-- ============================================================

/*
  SP_InsertObjetivoEntrenamiento
  ──────────────────────────────
  Inserta un nuevo objetivo de entrenamiento.
  Valida que el nombre no esté duplicado (restricción UQ ya existe
  en la tabla, pero el mensaje explícito mejora la experiencia).
  Retorna el ID generado via SCOPE_IDENTITY().
*/
CREATE PROCEDURE dbo.SP_InsertObjetivoEntrenamiento
    @nombre_objetivo  NVARCHAR(80),
    @descripcion      NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.OBJETIVO_ENTRENAMIENTO WHERE nombre_objetivo = @nombre_objetivo)
    BEGIN
        RAISERROR('Ya existe un objetivo con ese nombre.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.OBJETIVO_ENTRENAMIENTO (nombre_objetivo, descripcion)
    VALUES (@nombre_objetivo, @descripcion);

    SELECT SCOPE_IDENTITY() AS id_objetivo_entrenamiento_nuevo;
END;
GO

/*
  SP_ReadObjetivoEntrenamiento
  ────────────────────────────
  Lectura de uno o todos los objetivos.
  Si @id es NULL devuelve todos los registros.
  El patrón ISNULL(param, columna) actúa como filtro opcional
  sin necesidad de SQL dinámico.
*/
CREATE PROCEDURE dbo.SP_ReadObjetivoEntrenamiento
    @id_objetivo_entrenamiento INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_objetivo_entrenamiento, nombre_objetivo, descripcion
    FROM   dbo.OBJETIVO_ENTRENAMIENTO
    WHERE  id_objetivo_entrenamiento =
           ISNULL(@id_objetivo_entrenamiento, id_objetivo_entrenamiento)
    ORDER BY id_objetivo_entrenamiento;
END;
GO


-- ============================================================
-- 2. NIVEL_ALUMNO
-- ============================================================

/*
  SP_InsertNivelAlumno
  ─────────────────────
  Inserta un nuevo nivel con su porcentaje de incremento base.
  Valida el rango del porcentaje antes de insertar para complementar
  el CHECK constraint de la tabla con un mensaje de error claro.
*/
CREATE PROCEDURE dbo.SP_InsertNivelAlumno
    @nombre_nivel               NVARCHAR(50),
    @porcentaje_incremento_base DECIMAL(5,2),
    @descripcion                NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @porcentaje_incremento_base <= 0 OR @porcentaje_incremento_base > 100
    BEGIN
        RAISERROR('El porcentaje debe estar entre 0.01 y 100.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.NIVEL_ALUMNO (nombre_nivel, porcentaje_incremento_base, descripcion)
    VALUES (@nombre_nivel, @porcentaje_incremento_base, @descripcion);

    SELECT SCOPE_IDENTITY() AS id_nivel_alumno_nuevo;
END;
GO

/*
  SP_UpdateNivelAlumno
  ──────────────────────
  Actualiza porcentaje o descripción de un nivel existente.
  Patrón ISNULL: solo actualiza los campos que se pasan explícitamente,
  dejando el resto sin cambios. Permite actualizaciones parciales
  sin conocer el estado actual del registro.
*/
CREATE PROCEDURE dbo.SP_UpdateNivelAlumno
    @id_nivel_alumno            INT,
    @porcentaje_incremento_base DECIMAL(5,2)  = NULL,
    @descripcion                NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.NIVEL_ALUMNO WHERE id_nivel_alumno = @id_nivel_alumno)
    BEGIN
        RAISERROR('Nivel no encontrado.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.NIVEL_ALUMNO
    SET porcentaje_incremento_base = ISNULL(@porcentaje_incremento_base, porcentaje_incremento_base),
        descripcion                = ISNULL(@descripcion, descripcion)
    WHERE id_nivel_alumno = @id_nivel_alumno;
END;
GO


-- ============================================================
-- 3. COACH
-- ============================================================

/*
  SP_InsertCoach
  ──────────────
  Alta de coach. Valida unicidad de email antes de insertar.
  El estado inicial siempre es Activo (1), definido internamente:
  no se expone como parámetro para evitar altas en estado incorrecto.
*/
CREATE PROCEDURE dbo.SP_InsertCoach
    @nombre       NVARCHAR(80),
    @apellido     NVARCHAR(80),
    @email        NVARCHAR(120),
    @especialidad NVARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.COACH WHERE email = @email)
    BEGIN
        RAISERROR('El email ya está registrado para otro coach.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.COACH (nombre, apellido, email, especialidad, id_estado_coach)
    VALUES (@nombre, @apellido, @email, @especialidad, 1);

    SELECT SCOPE_IDENTITY() AS id_coach_nuevo;
END;
GO

/*
  SP_UpdateCoach
  ──────────────
  Actualización parcial de cualquier campo del coach, incluyendo estado.
  Si se pasa un email nuevo, verifica que no esté en uso por otro coach
  antes de aplicar el cambio (consulta excluyendo el propio registro).
*/
CREATE PROCEDURE dbo.SP_UpdateCoach
    @id_coach        INT,
    @nombre          NVARCHAR(80)  = NULL,
    @apellido        NVARCHAR(80)  = NULL,
    @email           NVARCHAR(120) = NULL,
    @especialidad    NVARCHAR(80)  = NULL,
    @id_estado_coach TINYINT       = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.COACH WHERE id_coach = @id_coach)
    BEGIN
        RAISERROR('Coach no encontrado.', 16, 1);
        RETURN;
    END;

    -- Valida email solo si se quiere cambiar
    IF @email IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.COACH WHERE email = @email AND id_coach <> @id_coach)
    BEGIN
        RAISERROR('El email ya está en uso por otro coach.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.COACH
    SET nombre          = ISNULL(@nombre,          nombre),
        apellido        = ISNULL(@apellido,         apellido),
        email           = ISNULL(@email,            email),
        especialidad    = ISNULL(@especialidad,     especialidad),
        id_estado_coach = ISNULL(@id_estado_coach,  id_estado_coach)
    WHERE id_coach = @id_coach;
END;
GO


-- ============================================================
-- 4. ALUMNO
-- ============================================================

/*
  SP_InsertAlumno
  ───────────────
  Alta de alumno con validación de coach activo.
  Regla de negocio: no se puede asignar un coach inactivo o suspendido.
  El estado inicial del alumno siempre es Activo (1).
  La fecha de alta por defecto es la fecha actual si no se especifica.
*/
CREATE PROCEDURE dbo.SP_InsertAlumno
    @id_coach                   INT,
    @id_nivel_alumno            INT,
    @id_objetivo_entrenamiento  INT           = NULL,
    @nombre                     NVARCHAR(80),
    @apellido                   NVARCHAR(80),
    @email                      NVARCHAR(120),
    @fecha_alta                 DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- El coach debe existir y estar activo
    IF NOT EXISTS (SELECT 1 FROM dbo.COACH WHERE id_coach = @id_coach AND id_estado_coach = 1)
    BEGIN
        RAISERROR('El coach indicado no existe o no está activo.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM dbo.ALUMNO WHERE email = @email)
    BEGIN
        RAISERROR('El email ya está registrado para otro alumno.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.ALUMNO
        (id_coach, id_nivel_alumno, id_objetivo_entrenamiento,
         id_estado_alumno, nombre, apellido, email, fecha_alta)
    VALUES
        (@id_coach, @id_nivel_alumno, @id_objetivo_entrenamiento,
         1, @nombre, @apellido, @email,
         ISNULL(@fecha_alta, CAST(GETDATE() AS DATE)));

    SELECT SCOPE_IDENTITY() AS id_alumno_nuevo;
END;
GO

/*
  SP_UpdateEstadoAlumno
  ──────────────────────
  Cambia el estado de un alumno (Activo / Pausado / Baja).
  Funciona como baja lógica cuando se pasa id_estado_alumno = 3.
  Valida que el estado destino exista en la tabla de dominio.
*/
CREATE PROCEDURE dbo.SP_UpdateEstadoAlumno
    @id_alumno        INT,
    @id_estado_alumno TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.ALUMNO WHERE id_alumno = @id_alumno)
    BEGIN
        RAISERROR('Alumno no encontrado.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.ESTADO_ALUMNO WHERE id_estado_alumno = @id_estado_alumno)
    BEGIN
        RAISERROR('Estado de alumno inválido.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.ALUMNO
    SET id_estado_alumno = @id_estado_alumno
    WHERE id_alumno = @id_alumno;
END;
GO


-- ============================================================
-- 5. RUTINA
-- ============================================================

/*
  SP_InsertRutina
  ───────────────
  Alta de rutina activa para un alumno.
  Aplica la regla de negocio del índice filtrado UX_RUTINA_activa_por_alumno:
  antes de insertar verifica explícitamente si ya existe una rutina activa.
  El mensaje de error resultante es más descriptivo que la excepción
  de violación de índice único que generaría la BD directamente.
*/
CREATE PROCEDURE dbo.SP_InsertRutina
    @id_alumno                  INT,
    @nombre                     NVARCHAR(100),
    @fecha_inicio               DATE,
    @id_objetivo_entrenamiento  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.ALUMNO WHERE id_alumno = @id_alumno AND id_estado_alumno = 1)
    BEGIN
        RAISERROR('El alumno no existe o no está activo.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM dbo.RUTINA WHERE id_alumno = @id_alumno AND id_estado_rutina = 1)
    BEGIN
        RAISERROR('El alumno ya posee una rutina activa. Finalícela antes de crear una nueva.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.RUTINA (id_alumno, id_objetivo_entrenamiento, id_estado_rutina, nombre, fecha_inicio)
    VALUES (@id_alumno, @id_objetivo_entrenamiento, 1, @nombre, @fecha_inicio);

    SELECT SCOPE_IDENTITY() AS id_rutina_nueva;
END;
GO

/*
  SP_UpdateRutina
  ───────────────
  Actualización parcial de rutina: permite cambiar nombre, objetivo,
  estado y/o fecha de fin. Útil para finalizar una rutina activa
  pasando id_estado_rutina = 2 y la fecha_fin correspondiente.
*/
CREATE PROCEDURE dbo.SP_UpdateRutina
    @id_rutina                  INT,
    @nombre                     NVARCHAR(100) = NULL,
    @id_objetivo_entrenamiento  INT           = NULL,
    @id_estado_rutina           TINYINT       = NULL,
    @fecha_fin                  DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.RUTINA WHERE id_rutina = @id_rutina)
    BEGIN
        RAISERROR('Rutina no encontrada.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.RUTINA
    SET nombre                    = ISNULL(@nombre,                    nombre),
        id_objetivo_entrenamiento = ISNULL(@id_objetivo_entrenamiento, id_objetivo_entrenamiento),
        id_estado_rutina          = ISNULL(@id_estado_rutina,          id_estado_rutina),
        fecha_fin                 = ISNULL(@fecha_fin,                 fecha_fin)
    WHERE id_rutina = @id_rutina;
END;
GO


-- ============================================================
-- 6. EJERCICIO
-- ============================================================

/*
  SP_InsertEjercicio
  ──────────────────
  Alta de ejercicio con validación de nombre único.
  El campo descripcion es opcional (NULL por defecto).
*/
CREATE PROCEDURE dbo.SP_InsertEjercicio
    @nombre         NVARCHAR(100),
    @grupo_muscular NVARCHAR(80),
    @tipo_ejercicio NVARCHAR(50),
    @descripcion    NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.EJERCICIO WHERE nombre = @nombre)
    BEGIN
        RAISERROR('Ya existe un ejercicio con ese nombre.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.EJERCICIO (nombre, grupo_muscular, tipo_ejercicio, descripcion)
    VALUES (@nombre, @grupo_muscular, @tipo_ejercicio, @descripcion);

    SELECT SCOPE_IDENTITY() AS id_ejercicio_nuevo;
END;
GO

/*
  SP_UpdateEjercicio
  ──────────────────
  Actualización parcial de cualquier campo del ejercicio.
  Permite corregir nombres, reclasificar grupo muscular o tipo
  sin necesidad de pasar todos los campos.
*/
CREATE PROCEDURE dbo.SP_UpdateEjercicio
    @id_ejercicio   INT,
    @nombre         NVARCHAR(100) = NULL,
    @grupo_muscular NVARCHAR(80)  = NULL,
    @tipo_ejercicio NVARCHAR(50)  = NULL,
    @descripcion    NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.EJERCICIO WHERE id_ejercicio = @id_ejercicio)
    BEGIN
        RAISERROR('Ejercicio no encontrado.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.EJERCICIO
    SET nombre         = ISNULL(@nombre,         nombre),
        grupo_muscular = ISNULL(@grupo_muscular,  grupo_muscular),
        tipo_ejercicio = ISNULL(@tipo_ejercicio,  tipo_ejercicio),
        descripcion    = ISNULL(@descripcion,     descripcion)
    WHERE id_ejercicio = @id_ejercicio;
END;
GO


-- ============================================================
-- 7. RUTINA_EJERCICIO
-- ============================================================

/*
  SP_InsertRutinaEjercicio
  ─────────────────────────
  Agrega un ejercicio a una rutina activa (prescripción).
  Valida que la rutina esté activa y que el ejercicio no esté
  ya incluido en ella (cumple la restricción UQ_RUTINA_EJERCICIO).
*/
CREATE PROCEDURE dbo.SP_InsertRutinaEjercicio
    @id_rutina             INT,
    @id_ejercicio          INT,
    @series_objetivo       INT,
    @repeticiones_objetivo INT,
    @peso_sugerido         DECIMAL(6,2),
    @rir_objetivo          INT,
    @observaciones         NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.RUTINA WHERE id_rutina = @id_rutina AND id_estado_rutina = 1)
    BEGIN
        RAISERROR('La rutina no existe o no está activa.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM dbo.RUTINA_EJERCICIO
               WHERE id_rutina = @id_rutina AND id_ejercicio = @id_ejercicio)
    BEGIN
        RAISERROR('El ejercicio ya está incluido en esta rutina.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.RUTINA_EJERCICIO
        (id_rutina, id_ejercicio, series_objetivo, repeticiones_objetivo,
         peso_sugerido, rir_objetivo, observaciones)
    VALUES
        (@id_rutina, @id_ejercicio, @series_objetivo, @repeticiones_objetivo,
         @peso_sugerido, @rir_objetivo, @observaciones);

    SELECT SCOPE_IDENTITY() AS id_rutina_ejercicio_nuevo;
END;
GO

/*
  SP_UpdatePesoSugeridoRutinaEjercicio
  ──────────────────────────────────────
  Actualiza el peso sugerido de una prescripción.
  Es la operación que normalmente ejecutaría el trigger
  TR_AplicarProgresionAlResolver de forma automática,
  pero se expone también como SP para ajustes manuales del coach.
*/
CREATE PROCEDURE dbo.SP_UpdatePesoSugeridoRutinaEjercicio
    @id_rutina_ejercicio INT,
    @peso_sugerido       DECIMAL(6,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.RUTINA_EJERCICIO WHERE id_rutina_ejercicio = @id_rutina_ejercicio)
    BEGIN
        RAISERROR('Prescripción (RUTINA_EJERCICIO) no encontrada.', 16, 1);
        RETURN;
    END;

    IF @peso_sugerido < 0
    BEGIN
        RAISERROR('El peso sugerido no puede ser negativo.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.RUTINA_EJERCICIO
    SET peso_sugerido = @peso_sugerido
    WHERE id_rutina_ejercicio = @id_rutina_ejercicio;
END;
GO


-- ============================================================
-- 8. SESION_ENTRENAMIENTO
-- ============================================================

/*
  SP_InsertSesionEntrenamiento
  ─────────────────────────────
  Registra una nueva sesión de entrenamiento.
  Valida la unicidad (alumno, fecha) antes de insertar
  para dar un mensaje claro en lugar de la excepción de constraint.
  El trigger TR_ValidarAlumnoActivoEnSesion validará el estado del alumno.
*/
CREATE PROCEDURE dbo.SP_InsertSesionEntrenamiento
    @id_alumno             INT,
    @fecha                 DATE,
    @id_estado_sesion      TINYINT       = 1,
    @comentarios_generales NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.SESION_ENTRENAMIENTO
               WHERE id_alumno = @id_alumno AND fecha = @fecha)
    BEGIN
        RAISERROR('Ya existe una sesión para este alumno en la fecha indicada.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.SESION_ENTRENAMIENTO
        (id_alumno, id_estado_sesion, fecha, comentarios_generales)
    VALUES
        (@id_alumno, @id_estado_sesion, @fecha, @comentarios_generales);

    SELECT SCOPE_IDENTITY() AS id_sesion_nueva;
END;
GO

/*
  SP_UpdateEstadoSesion
  ──────────────────────
  Modifica el estado de una sesión (Completa / Parcial / Cancelada)
  y opcionalmente actualiza los comentarios generales.
  Útil para marcar una sesión como Cancelada post-registro.
*/
CREATE PROCEDURE dbo.SP_UpdateEstadoSesion
    @id_sesion             INT,
    @id_estado_sesion      TINYINT,
    @comentarios_generales NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.SESION_ENTRENAMIENTO WHERE id_sesion = @id_sesion)
    BEGIN
        RAISERROR('Sesión no encontrada.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.SESION_ENTRENAMIENTO
    SET id_estado_sesion      = @id_estado_sesion,
        comentarios_generales = ISNULL(@comentarios_generales, comentarios_generales)
    WHERE id_sesion = @id_sesion;
END;
GO


-- ============================================================
-- 9. REGISTRO_EJERCICIO
-- ============================================================

/*
  SP_InsertRegistroEjercicio
  ───────────────────────────
  Registra la ejecución de un ejercicio dentro de una sesión.
  Verifica la restricción UQ_REGISTRO_EJERCICIO_sesion_rutina
  antes de insertar para dar un error descriptivo.
*/
CREATE PROCEDURE dbo.SP_InsertRegistroEjercicio
    @id_sesion               INT,
    @id_rutina_ejercicio     INT,
    @series_realizadas       INT,
    @repeticiones_realizadas INT,
    @peso_utilizado          DECIMAL(6,2),
    @rir_promedio            INT,
    @observaciones           NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.REGISTRO_EJERCICIO
               WHERE id_sesion = @id_sesion AND id_rutina_ejercicio = @id_rutina_ejercicio)
    BEGIN
        RAISERROR('Ya existe un registro para esta prescripción en la sesión indicada.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.REGISTRO_EJERCICIO
        (id_sesion, id_rutina_ejercicio, series_realizadas, repeticiones_realizadas,
         peso_utilizado, rir_promedio, observaciones)
    VALUES
        (@id_sesion, @id_rutina_ejercicio, @series_realizadas, @repeticiones_realizadas,
         @peso_utilizado, @rir_promedio, @observaciones);

    SELECT SCOPE_IDENTITY() AS id_registro_nuevo;
END;
GO

/*
  SP_DeleteRegistroEjercicio
  ───────────────────────────
  Eliminación física de un registro de ejercicio.
  Es la única operación de DELETE expuesta en este TP
  ya que los registros individuales pueden necesitar corrección
  sin dar de baja la sesión completa.
*/
CREATE PROCEDURE dbo.SP_DeleteRegistroEjercicio
    @id_registro INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.REGISTRO_EJERCICIO WHERE id_registro = @id_registro)
    BEGIN
        RAISERROR('Registro de ejercicio no encontrado.', 16, 1);
        RETURN;
    END;

    DELETE FROM dbo.REGISTRO_EJERCICIO WHERE id_registro = @id_registro;
END;
GO


-- ============================================================
-- 10. SUGERENCIA_PROGRESION
-- ============================================================

/*
  SP_InsertSugerenciaProgresion
  ──────────────────────────────
  Crea una sugerencia de progresión para una prescripción (RUTINA_EJERCICIO).
  Valida dos condiciones críticas antes de insertar:
    a) No puede haber otra sugerencia Pendiente para la misma prescripción
       (complementa el índice filtrado UX_SUGERENCIA_pendiente_por_prescripcion).
    b) El peso sugerido debe ser mayor o igual al peso actual
       (complementa el CHECK constraint de la tabla).
*/
CREATE PROCEDURE dbo.SP_InsertSugerenciaProgresion
    @id_rutina_ejercicio   INT,
    @peso_actual           DECIMAL(6,2),
    @peso_sugerido         DECIMAL(6,2),
    @porcentaje_incremento DECIMAL(5,2),
    @motivo                NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.SUGERENCIA_PROGRESION
               WHERE id_rutina_ejercicio = @id_rutina_ejercicio
                 AND id_estado_sugerencia = 1)
    BEGIN
        RAISERROR('Ya existe una sugerencia Pendiente para esta prescripción.', 16, 1);
        RETURN;
    END;

    IF @peso_sugerido < @peso_actual
    BEGIN
        RAISERROR('El peso sugerido no puede ser menor al peso actual.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.SUGERENCIA_PROGRESION
        (id_rutina_ejercicio, id_estado_sugerencia, fecha_sugerencia,
         peso_actual, peso_sugerido, porcentaje_incremento, motivo)
    VALUES
        (@id_rutina_ejercicio, 1, CAST(GETDATE() AS DATE),
         @peso_actual, @peso_sugerido, @porcentaje_incremento, @motivo);

    SELECT SCOPE_IDENTITY() AS id_sugerencia_nueva;
END;
GO

/*
  SP_ResolverSugerenciaProgresion
  ────────────────────────────────
  Cambia el estado de una sugerencia Pendiente (1) a:
    2 = Aprobada  : el coach acepta pero no aplica aún
    3 = Rechazada : el coach descarta la sugerencia
    4 = Aplicada  : el trigger TR_AplicarProgresionAlResolver
                    actualizará automáticamente RUTINA_EJERCICIO.peso_sugerido
  Solo acepta sugerencias en estado Pendiente para evitar
  resoluciones dobles.
*/
CREATE PROCEDURE dbo.SP_ResolverSugerenciaProgresion
    @id_sugerencia        INT,
    @id_estado_sugerencia TINYINT   -- 2=Aprobada, 3=Rechazada, 4=Aplicada
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.SUGERENCIA_PROGRESION
                   WHERE id_sugerencia = @id_sugerencia AND id_estado_sugerencia = 1)
    BEGIN
        RAISERROR('Sugerencia no encontrada o no está en estado Pendiente.', 16, 1);
        RETURN;
    END;

    IF @id_estado_sugerencia NOT IN (2, 3, 4)
    BEGIN
        RAISERROR('Estado destino inválido. Use 2=Aprobada, 3=Rechazada o 4=Aplicada.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.SUGERENCIA_PROGRESION
    SET id_estado_sugerencia = @id_estado_sugerencia
    WHERE id_sugerencia = @id_sugerencia;
    -- Si estado = 4, el trigger TR_AplicarProgresionAlResolver
    -- actualiza RUTINA_EJERCICIO.peso_sugerido automáticamente.
END;
GO


-- ============================================================
-- 11. HISTORIAL_PROGRESION
-- ============================================================

/*
  SP_InsertHistorialProgresion
  ─────────────────────────────
  Registra el resultado de la resolución de una sugerencia.
  Verifica que la sugerencia exista y que no tenga ya un historial
  (restricción UQ_HISTORIAL_id_sugerencia: 1 historial por sugerencia).
  Normalmente se llama luego de SP_ResolverSugerenciaProgresion.
*/
CREATE PROCEDURE dbo.SP_InsertHistorialProgresion
    @id_sugerencia        INT,
    @id_accion_progresion TINYINT,
    @peso_anterior        DECIMAL(6,2),
    @peso_nuevo           DECIMAL(6,2),
    @observaciones        NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.SUGERENCIA_PROGRESION WHERE id_sugerencia = @id_sugerencia)
    BEGIN
        RAISERROR('Sugerencia no encontrada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM dbo.HISTORIAL_PROGRESION WHERE id_sugerencia = @id_sugerencia)
    BEGIN
        RAISERROR('Ya existe un historial para esta sugerencia.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.HISTORIAL_PROGRESION
        (id_sugerencia, id_accion_progresion, fecha_resolucion,
         peso_anterior, peso_nuevo, observaciones)
    VALUES
        (@id_sugerencia, @id_accion_progresion, CAST(GETDATE() AS DATE),
         @peso_anterior, @peso_nuevo, @observaciones);

    SELECT SCOPE_IDENTITY() AS id_historial_nuevo;
END;
GO

/*
  SP_ReadHistorialByAlumno
  ─────────────────────────
  Devuelve el historial completo de progresiones de un alumno,
  recorriendo la cadena: HISTORIAL → SUGERENCIA → RUTINA_EJERCICIO
  → EJERCICIO y RUTINA → ALUMNO.
  Incluye la diferencia de peso (peso_nuevo - peso_anterior)
  como columna calculada en la consulta.
  Ordenado por fecha descendente para ver lo más reciente primero.
*/
CREATE PROCEDURE dbo.SP_ReadHistorialByAlumno
    @id_alumno INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.id_historial,
        h.fecha_resolucion,
        ap.nombre_accion                       AS accion,
        e.nombre                               AS ejercicio,
        e.grupo_muscular,
        ru.nombre                              AS rutina,
        h.peso_anterior,
        h.peso_nuevo,
        h.peso_nuevo - h.peso_anterior         AS diferencia_kg,
        ISNULL(h.observaciones, N'-')          AS observaciones
    FROM  dbo.HISTORIAL_PROGRESION    h
    INNER JOIN dbo.ACCION_PROGRESION   ap ON ap.id_accion_progresion   = h.id_accion_progresion
    INNER JOIN dbo.SUGERENCIA_PROGRESION sp ON sp.id_sugerencia        = h.id_sugerencia
    INNER JOIN dbo.RUTINA_EJERCICIO     re ON re.id_rutina_ejercicio   = sp.id_rutina_ejercicio
    INNER JOIN dbo.EJERCICIO             e ON e.id_ejercicio           = re.id_ejercicio
    INNER JOIN dbo.RUTINA               ru ON ru.id_rutina             = re.id_rutina
    WHERE  ru.id_alumno = @id_alumno
    ORDER BY h.fecha_resolucion DESC;
END;
GO
