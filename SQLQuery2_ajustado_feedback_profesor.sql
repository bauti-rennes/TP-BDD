IF DB_ID(N'CoachesOnlineDB') IS NULL
BEGIN
    CREATE DATABASE CoachesOnlineDB;
END;
GO

USE CoachesOnlineDB;
GO

/*
    Script ajustado según feedback docente.

    Cambios principales:
    1) Normalización de estados y acciones mediante tablas de dominio.
    2) Normalización de objetivo mediante OBJETIVO_ENTRENAMIENTO.
    3) Eliminación del atributo derivable completado en REGISTRO_EJERCICIO.
    4) SUGERENCIA_PROGRESION pasa a depender de RUTINA_EJERCICIO.
    5) Restricciones de integridad y unicidad adicionales.
*/

DROP VIEW IF EXISTS dbo.vw_RegistroEjercicioCumplimiento;
GO

DROP TABLE IF EXISTS dbo.HISTORIAL_PROGRESION;
DROP TABLE IF EXISTS dbo.SUGERENCIA_PROGRESION;
DROP TABLE IF EXISTS dbo.REGISTRO_EJERCICIO;
DROP TABLE IF EXISTS dbo.SESION_ENTRENAMIENTO;
DROP TABLE IF EXISTS dbo.RUTINA_EJERCICIO;
DROP TABLE IF EXISTS dbo.EJERCICIO;
DROP TABLE IF EXISTS dbo.RUTINA;
DROP TABLE IF EXISTS dbo.ALUMNO;
DROP TABLE IF EXISTS dbo.COACH;

DROP TABLE IF EXISTS dbo.ACCION_PROGRESION;
DROP TABLE IF EXISTS dbo.ESTADO_SUGERENCIA;
DROP TABLE IF EXISTS dbo.ESTADO_SESION;
DROP TABLE IF EXISTS dbo.ESTADO_RUTINA;
DROP TABLE IF EXISTS dbo.ESTADO_ALUMNO;
DROP TABLE IF EXISTS dbo.ESTADO_COACH;
DROP TABLE IF EXISTS dbo.OBJETIVO_ENTRENAMIENTO;
DROP TABLE IF EXISTS dbo.NIVEL_ALUMNO;
GO

/* ============================================================
   TABLAS DE DOMINIO
   ============================================================ */

CREATE TABLE dbo.ESTADO_COACH (
    id_estado_coach TINYINT NOT NULL,
    nombre_estado NVARCHAR(30) NOT NULL,

    CONSTRAINT PK_ESTADO_COACH PRIMARY KEY (id_estado_coach),
    CONSTRAINT UQ_ESTADO_COACH_nombre UNIQUE (nombre_estado)
);
GO

CREATE TABLE dbo.ESTADO_ALUMNO (
    id_estado_alumno TINYINT NOT NULL,
    nombre_estado NVARCHAR(30) NOT NULL,

    CONSTRAINT PK_ESTADO_ALUMNO PRIMARY KEY (id_estado_alumno),
    CONSTRAINT UQ_ESTADO_ALUMNO_nombre UNIQUE (nombre_estado)
);
GO

CREATE TABLE dbo.ESTADO_RUTINA (
    id_estado_rutina TINYINT NOT NULL,
    nombre_estado NVARCHAR(30) NOT NULL,

    CONSTRAINT PK_ESTADO_RUTINA PRIMARY KEY (id_estado_rutina),
    CONSTRAINT UQ_ESTADO_RUTINA_nombre UNIQUE (nombre_estado)
);
GO

CREATE TABLE dbo.ESTADO_SESION (
    id_estado_sesion TINYINT NOT NULL,
    nombre_estado NVARCHAR(30) NOT NULL,

    CONSTRAINT PK_ESTADO_SESION PRIMARY KEY (id_estado_sesion),
    CONSTRAINT UQ_ESTADO_SESION_nombre UNIQUE (nombre_estado)
);
GO

CREATE TABLE dbo.ESTADO_SUGERENCIA (
    id_estado_sugerencia TINYINT NOT NULL,
    nombre_estado NVARCHAR(30) NOT NULL,

    CONSTRAINT PK_ESTADO_SUGERENCIA PRIMARY KEY (id_estado_sugerencia),
    CONSTRAINT UQ_ESTADO_SUGERENCIA_nombre UNIQUE (nombre_estado)
);
GO

CREATE TABLE dbo.ACCION_PROGRESION (
    id_accion_progresion TINYINT NOT NULL,
    nombre_accion NVARCHAR(30) NOT NULL,

    CONSTRAINT PK_ACCION_PROGRESION PRIMARY KEY (id_accion_progresion),
    CONSTRAINT UQ_ACCION_PROGRESION_nombre UNIQUE (nombre_accion)
);
GO

CREATE TABLE dbo.OBJETIVO_ENTRENAMIENTO (
    id_objetivo_entrenamiento INT IDENTITY(1,1) NOT NULL,
    nombre_objetivo NVARCHAR(80) NOT NULL,
    descripcion NVARCHAR(250) NULL,

    CONSTRAINT PK_OBJETIVO_ENTRENAMIENTO PRIMARY KEY (id_objetivo_entrenamiento),
    CONSTRAINT UQ_OBJETIVO_ENTRENAMIENTO_nombre UNIQUE (nombre_objetivo)
);
GO

CREATE TABLE dbo.NIVEL_ALUMNO (
    id_nivel_alumno INT IDENTITY(1,1) NOT NULL,
    nombre_nivel NVARCHAR(50) NOT NULL,
    porcentaje_incremento_base DECIMAL(5,2) NOT NULL,
    descripcion NVARCHAR(250) NULL,

    CONSTRAINT PK_NIVEL_ALUMNO PRIMARY KEY (id_nivel_alumno),
    CONSTRAINT UQ_NIVEL_ALUMNO_nombre UNIQUE (nombre_nivel),
    CONSTRAINT CK_NIVEL_ALUMNO_porcentaje
        CHECK (porcentaje_incremento_base > 0 AND porcentaje_incremento_base <= 100)
);
GO

/* ============================================================
   CARGA BASE DE DOMINIOS
   ============================================================ */

INSERT INTO dbo.ESTADO_COACH (id_estado_coach, nombre_estado)
VALUES (1, N'Activo'), (2, N'Inactivo'), (3, N'Suspendido');

INSERT INTO dbo.ESTADO_ALUMNO (id_estado_alumno, nombre_estado)
VALUES (1, N'Activo'), (2, N'Pausado'), (3, N'Baja');

INSERT INTO dbo.ESTADO_RUTINA (id_estado_rutina, nombre_estado)
VALUES (1, N'Activa'), (2, N'Finalizada'), (3, N'Pausada');

INSERT INTO dbo.ESTADO_SESION (id_estado_sesion, nombre_estado)
VALUES (1, N'Completa'), (2, N'Parcial'), (3, N'Cancelada');

INSERT INTO dbo.ESTADO_SUGERENCIA (id_estado_sugerencia, nombre_estado)
VALUES (1, N'Pendiente'), (2, N'Aprobada'), (3, N'Rechazada'), (4, N'Aplicada');

INSERT INTO dbo.ACCION_PROGRESION (id_accion_progresion, nombre_accion)
VALUES (1, N'Aprobada'), (2, N'Rechazada'), (3, N'Modificada');

INSERT INTO dbo.OBJETIVO_ENTRENAMIENTO (nombre_objetivo, descripcion)
VALUES
    (N'Fuerza', N'Mejora de fuerza máxima o relativa.'),
    (N'Hipertrofia', N'Aumento de masa muscular.'),
    (N'Rendimiento', N'Mejora de performance deportiva.'),
    (N'Recomposición corporal', N'Mejora simultánea de composición corporal y rendimiento.'),
    (N'Salud general', N'Entrenamiento orientado a bienestar y adherencia.');

INSERT INTO dbo.NIVEL_ALUMNO (nombre_nivel, porcentaje_incremento_base, descripcion)
VALUES
    (N'Novato', 7.50, N'Puede progresar con incrementos más altos por adaptación inicial.'),
    (N'Intermedio', 5.00, N'Progresión moderada.'),
    (N'Avanzado', 2.50, N'Progresión más conservadora por cercanía a límites de rendimiento.');
GO

/* ============================================================
   ENTIDADES PRINCIPALES
   ============================================================ */

CREATE TABLE dbo.COACH (
    id_coach INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(80) NOT NULL,
    apellido NVARCHAR(80) NOT NULL,
    email NVARCHAR(120) NOT NULL,
    especialidad NVARCHAR(80) NULL,
    id_estado_coach TINYINT NOT NULL CONSTRAINT DF_COACH_estado DEFAULT 1,

    CONSTRAINT PK_COACH PRIMARY KEY (id_coach),
    CONSTRAINT UQ_COACH_email UNIQUE (email),
    CONSTRAINT FK_COACH_ESTADO_COACH
        FOREIGN KEY (id_estado_coach) REFERENCES dbo.ESTADO_COACH(id_estado_coach)
);
GO

CREATE TABLE dbo.ALUMNO (
    id_alumno INT IDENTITY(1,1) NOT NULL,
    id_coach INT NOT NULL,
    id_nivel_alumno INT NOT NULL,
    id_objetivo_entrenamiento INT NULL,
    id_estado_alumno TINYINT NOT NULL CONSTRAINT DF_ALUMNO_estado DEFAULT 1,
    nombre NVARCHAR(80) NOT NULL,
    apellido NVARCHAR(80) NOT NULL,
    email NVARCHAR(120) NOT NULL,
    fecha_alta DATE NOT NULL CONSTRAINT DF_ALUMNO_fecha_alta DEFAULT CAST(GETDATE() AS DATE),

    CONSTRAINT PK_ALUMNO PRIMARY KEY (id_alumno),
    CONSTRAINT UQ_ALUMNO_email UNIQUE (email),

    CONSTRAINT FK_ALUMNO_COACH
        FOREIGN KEY (id_coach) REFERENCES dbo.COACH(id_coach),

    CONSTRAINT FK_ALUMNO_NIVEL_ALUMNO
        FOREIGN KEY (id_nivel_alumno) REFERENCES dbo.NIVEL_ALUMNO(id_nivel_alumno),

    CONSTRAINT FK_ALUMNO_OBJETIVO_ENTRENAMIENTO
        FOREIGN KEY (id_objetivo_entrenamiento)
        REFERENCES dbo.OBJETIVO_ENTRENAMIENTO(id_objetivo_entrenamiento),

    CONSTRAINT FK_ALUMNO_ESTADO_ALUMNO
        FOREIGN KEY (id_estado_alumno) REFERENCES dbo.ESTADO_ALUMNO(id_estado_alumno)
);
GO

CREATE TABLE dbo.RUTINA (
    id_rutina INT IDENTITY(1,1) NOT NULL,
    id_alumno INT NOT NULL,
    id_objetivo_entrenamiento INT NULL,
    id_estado_rutina TINYINT NOT NULL CONSTRAINT DF_RUTINA_estado DEFAULT 1,
    nombre NVARCHAR(100) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    CONSTRAINT PK_RUTINA PRIMARY KEY (id_rutina),

    CONSTRAINT FK_RUTINA_ALUMNO
        FOREIGN KEY (id_alumno) REFERENCES dbo.ALUMNO(id_alumno),

    CONSTRAINT FK_RUTINA_OBJETIVO_ENTRENAMIENTO
        FOREIGN KEY (id_objetivo_entrenamiento)
        REFERENCES dbo.OBJETIVO_ENTRENAMIENTO(id_objetivo_entrenamiento),

    CONSTRAINT FK_RUTINA_ESTADO_RUTINA
        FOREIGN KEY (id_estado_rutina) REFERENCES dbo.ESTADO_RUTINA(id_estado_rutina),

    CONSTRAINT CK_RUTINA_fechas
        CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),

    CONSTRAINT UQ_RUTINA_alumno_nombre_inicio
        UNIQUE (id_alumno, nombre, fecha_inicio)
);
GO

CREATE TABLE dbo.EJERCICIO (
    id_ejercicio INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    grupo_muscular NVARCHAR(80) NOT NULL,
    tipo_ejercicio NVARCHAR(50) NOT NULL,
    descripcion NVARCHAR(250) NULL,

    CONSTRAINT PK_EJERCICIO PRIMARY KEY (id_ejercicio),
    CONSTRAINT UQ_EJERCICIO_nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.RUTINA_EJERCICIO (
    id_rutina_ejercicio INT IDENTITY(1,1) NOT NULL,
    id_rutina INT NOT NULL,
    id_ejercicio INT NOT NULL,
    series_objetivo INT NOT NULL,
    repeticiones_objetivo INT NOT NULL,
    peso_sugerido DECIMAL(6,2) NOT NULL,
    rir_objetivo INT NOT NULL,
    observaciones NVARCHAR(250) NULL,

    CONSTRAINT PK_RUTINA_EJERCICIO PRIMARY KEY (id_rutina_ejercicio),

    CONSTRAINT FK_RUTINA_EJERCICIO_RUTINA
        FOREIGN KEY (id_rutina) REFERENCES dbo.RUTINA(id_rutina),

    CONSTRAINT FK_RUTINA_EJERCICIO_EJERCICIO
        FOREIGN KEY (id_ejercicio) REFERENCES dbo.EJERCICIO(id_ejercicio),

    CONSTRAINT UQ_RUTINA_EJERCICIO_rutina_ejercicio
        UNIQUE (id_rutina, id_ejercicio),

    CONSTRAINT CK_RUTINA_EJERCICIO_series
        CHECK (series_objetivo > 0),

    CONSTRAINT CK_RUTINA_EJERCICIO_repeticiones
        CHECK (repeticiones_objetivo > 0),

    CONSTRAINT CK_RUTINA_EJERCICIO_peso
        CHECK (peso_sugerido >= 0),

    CONSTRAINT CK_RUTINA_EJERCICIO_rir
        CHECK (rir_objetivo BETWEEN 0 AND 10)
);
GO

CREATE TABLE dbo.SESION_ENTRENAMIENTO (
    id_sesion INT IDENTITY(1,1) NOT NULL,
    id_alumno INT NOT NULL,
    id_estado_sesion TINYINT NOT NULL CONSTRAINT DF_SESION_estado DEFAULT 1,
    fecha DATE NOT NULL,
    comentarios_generales NVARCHAR(300) NULL,

    CONSTRAINT PK_SESION_ENTRENAMIENTO PRIMARY KEY (id_sesion),

    CONSTRAINT FK_SESION_ENTRENAMIENTO_ALUMNO
        FOREIGN KEY (id_alumno) REFERENCES dbo.ALUMNO(id_alumno),

    CONSTRAINT FK_SESION_ENTRENAMIENTO_ESTADO_SESION
        FOREIGN KEY (id_estado_sesion) REFERENCES dbo.ESTADO_SESION(id_estado_sesion),

    CONSTRAINT UQ_SESION_ENTRENAMIENTO_alumno_fecha
        UNIQUE (id_alumno, fecha)
);
GO

CREATE TABLE dbo.REGISTRO_EJERCICIO (
    id_registro INT IDENTITY(1,1) NOT NULL,
    id_sesion INT NOT NULL,
    id_rutina_ejercicio INT NOT NULL,
    series_realizadas INT NOT NULL,
    repeticiones_realizadas INT NOT NULL,
    peso_utilizado DECIMAL(6,2) NOT NULL,
    rir_promedio INT NOT NULL,
    observaciones NVARCHAR(250) NULL,

    CONSTRAINT PK_REGISTRO_EJERCICIO PRIMARY KEY (id_registro),

    CONSTRAINT FK_REGISTRO_EJERCICIO_SESION
        FOREIGN KEY (id_sesion) REFERENCES dbo.SESION_ENTRENAMIENTO(id_sesion),

    CONSTRAINT FK_REGISTRO_EJERCICIO_RUTINA_EJERCICIO
        FOREIGN KEY (id_rutina_ejercicio) REFERENCES dbo.RUTINA_EJERCICIO(id_rutina_ejercicio),

    CONSTRAINT CK_REGISTRO_EJERCICIO_series
        CHECK (series_realizadas >= 0),

    CONSTRAINT CK_REGISTRO_EJERCICIO_repeticiones
        CHECK (repeticiones_realizadas >= 0),

    CONSTRAINT CK_REGISTRO_EJERCICIO_peso
        CHECK (peso_utilizado >= 0),

    CONSTRAINT CK_REGISTRO_EJERCICIO_rir
        CHECK (rir_promedio BETWEEN 0 AND 10),

    CONSTRAINT UQ_REGISTRO_EJERCICIO_sesion_rutina
        UNIQUE (id_sesion, id_rutina_ejercicio)
);
GO

CREATE TABLE dbo.SUGERENCIA_PROGRESION (
    id_sugerencia INT IDENTITY(1,1) NOT NULL,
    id_rutina_ejercicio INT NOT NULL,
    id_estado_sugerencia TINYINT NOT NULL CONSTRAINT DF_SUGERENCIA_estado DEFAULT 1,
    fecha_sugerencia DATE NOT NULL CONSTRAINT DF_SUGERENCIA_fecha DEFAULT CAST(GETDATE() AS DATE),
    peso_actual DECIMAL(6,2) NOT NULL,
    peso_sugerido DECIMAL(6,2) NOT NULL,
    porcentaje_incremento DECIMAL(5,2) NOT NULL,
    motivo NVARCHAR(300) NOT NULL,

    CONSTRAINT PK_SUGERENCIA_PROGRESION PRIMARY KEY (id_sugerencia),

    CONSTRAINT FK_SUGERENCIA_RUTINA_EJERCICIO
        FOREIGN KEY (id_rutina_ejercicio)
        REFERENCES dbo.RUTINA_EJERCICIO(id_rutina_ejercicio),

    CONSTRAINT FK_SUGERENCIA_ESTADO_SUGERENCIA
        FOREIGN KEY (id_estado_sugerencia)
        REFERENCES dbo.ESTADO_SUGERENCIA(id_estado_sugerencia),

    CONSTRAINT CK_SUGERENCIA_peso_actual
        CHECK (peso_actual >= 0),

    CONSTRAINT CK_SUGERENCIA_peso_sugerido
        CHECK (peso_sugerido >= 0),

    CONSTRAINT CK_SUGERENCIA_porcentaje
        CHECK (porcentaje_incremento > 0 AND porcentaje_incremento <= 100),

    CONSTRAINT CK_SUGERENCIA_incremento_real
        CHECK (peso_sugerido >= peso_actual)
);
GO

CREATE TABLE dbo.HISTORIAL_PROGRESION (
    id_historial INT IDENTITY(1,1) NOT NULL,
    id_sugerencia INT NOT NULL,
    id_accion_progresion TINYINT NOT NULL,
    fecha_resolucion DATE NOT NULL CONSTRAINT DF_HISTORIAL_fecha DEFAULT CAST(GETDATE() AS DATE),
    peso_anterior DECIMAL(6,2) NOT NULL,
    peso_nuevo DECIMAL(6,2) NOT NULL,
    observaciones NVARCHAR(300) NULL,

    CONSTRAINT PK_HISTORIAL_PROGRESION PRIMARY KEY (id_historial),

    CONSTRAINT FK_HISTORIAL_SUGERENCIA
        FOREIGN KEY (id_sugerencia) REFERENCES dbo.SUGERENCIA_PROGRESION(id_sugerencia),

    CONSTRAINT FK_HISTORIAL_ACCION_PROGRESION
        FOREIGN KEY (id_accion_progresion)
        REFERENCES dbo.ACCION_PROGRESION(id_accion_progresion),

    CONSTRAINT UQ_HISTORIAL_id_sugerencia UNIQUE (id_sugerencia),

    CONSTRAINT CK_HISTORIAL_peso_anterior
        CHECK (peso_anterior >= 0),

    CONSTRAINT CK_HISTORIAL_peso_nuevo
        CHECK (peso_nuevo >= 0)
);
GO

/* ============================================================
   ÍNDICES Y RESTRICCIONES DE UNICIDAD FUNCIONAL
   ============================================================ */

CREATE INDEX IX_ALUMNO_id_coach
ON dbo.ALUMNO(id_coach);

CREATE INDEX IX_ALUMNO_id_nivel_alumno
ON dbo.ALUMNO(id_nivel_alumno);

CREATE INDEX IX_ALUMNO_id_objetivo_entrenamiento
ON dbo.ALUMNO(id_objetivo_entrenamiento);

CREATE INDEX IX_RUTINA_id_alumno
ON dbo.RUTINA(id_alumno);

CREATE INDEX IX_RUTINA_id_objetivo_entrenamiento
ON dbo.RUTINA(id_objetivo_entrenamiento);

CREATE INDEX IX_RUTINA_EJERCICIO_id_rutina
ON dbo.RUTINA_EJERCICIO(id_rutina);

CREATE INDEX IX_RUTINA_EJERCICIO_id_ejercicio
ON dbo.RUTINA_EJERCICIO(id_ejercicio);

CREATE INDEX IX_SESION_id_alumno_fecha
ON dbo.SESION_ENTRENAMIENTO(id_alumno, fecha);

CREATE INDEX IX_REGISTRO_id_sesion
ON dbo.REGISTRO_EJERCICIO(id_sesion);

CREATE INDEX IX_REGISTRO_id_rutina_ejercicio
ON dbo.REGISTRO_EJERCICIO(id_rutina_ejercicio);

CREATE INDEX IX_SUGERENCIA_id_rutina_ejercicio_estado
ON dbo.SUGERENCIA_PROGRESION(id_rutina_ejercicio, id_estado_sugerencia);

CREATE INDEX IX_HISTORIAL_id_accion_progresion
ON dbo.HISTORIAL_PROGRESION(id_accion_progresion);
GO

/*
    Evita más de una sugerencia pendiente para la misma prescripción.
    Como ESTADO_SUGERENCIA.Pendiente se carga con id 1, el índice filtrado
    queda estable y no depende de una subconsulta.
*/
CREATE UNIQUE INDEX UX_SUGERENCIA_pendiente_por_prescripcion
ON dbo.SUGERENCIA_PROGRESION(id_rutina_ejercicio)
WHERE id_estado_sugerencia = 1;
GO

/*
    Evita más de una rutina activa por alumno.
    Como ESTADO_RUTINA.Activa se carga con id 1, el índice filtrado queda estable.
*/
CREATE UNIQUE INDEX UX_RUTINA_activa_por_alumno
ON dbo.RUTINA(id_alumno)
WHERE id_estado_rutina = 1;
GO

/* ============================================================
   VISTA PARA ATRIBUTO DERIVADO: COMPLETADO
   ============================================================ */

CREATE VIEW dbo.vw_RegistroEjercicioCumplimiento
AS
SELECT
    re.id_registro,
    se.id_sesion,
    se.id_alumno,
    r.id_rutina,
    re.id_rutina_ejercicio,
    ru_ej.id_ejercicio,
    re.series_realizadas,
    re.repeticiones_realizadas,
    re.peso_utilizado,
    re.rir_promedio,
    ru_ej.series_objetivo,
    ru_ej.repeticiones_objetivo,
    ru_ej.peso_sugerido AS peso_objetivo,
    ru_ej.rir_objetivo,
    CAST(re.series_realizadas * re.repeticiones_realizadas * re.peso_utilizado AS DECIMAL(10,2)) AS volumen_total,
    CASE
        WHEN re.series_realizadas >= ru_ej.series_objetivo
         AND re.repeticiones_realizadas >= ru_ej.repeticiones_objetivo
        THEN CAST(1 AS BIT)
        ELSE CAST(0 AS BIT)
    END AS completado_calculado
FROM dbo.REGISTRO_EJERCICIO re
INNER JOIN dbo.SESION_ENTRENAMIENTO se
    ON se.id_sesion = re.id_sesion
INNER JOIN dbo.RUTINA_EJERCICIO ru_ej
    ON ru_ej.id_rutina_ejercicio = re.id_rutina_ejercicio
INNER JOIN dbo.RUTINA r
    ON r.id_rutina = ru_ej.id_rutina;
GO
