IF DB_ID(N'CoachesOnlineDB') IS NULL
BEGIN
    CREATE DATABASE CoachesOnlineDB;
END;
GO

USE CoachesOnlineDB;
GO

/* 
   Borrado en orden inverso por dependencias.
   Esto permite volver a ejecutar el script si están practicando.
*/

DROP TABLE IF EXISTS dbo.HISTORIAL_PROGRESION;
DROP TABLE IF EXISTS dbo.SUGERENCIA_PROGRESION;
DROP TABLE IF EXISTS dbo.REGISTRO_EJERCICIO;
DROP TABLE IF EXISTS dbo.SESION_ENTRENAMIENTO;
DROP TABLE IF EXISTS dbo.RUTINA_EJERCICIO;
DROP TABLE IF EXISTS dbo.EJERCICIO;
DROP TABLE IF EXISTS dbo.RUTINA;
DROP TABLE IF EXISTS dbo.ALUMNO;
DROP TABLE IF EXISTS dbo.NIVEL_ALUMNO;
DROP TABLE IF EXISTS dbo.COACH;
GO


-- TABLA 1: COACH

CREATE TABLE dbo.COACH (
    id_coach INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(80) NOT NULL,
    apellido NVARCHAR(80) NOT NULL,
    email NVARCHAR(120) NOT NULL,
    especialidad NVARCHAR(80) NULL,
    estado NVARCHAR(20) NOT NULL CONSTRAINT DF_COACH_estado DEFAULT 'Activo',

    CONSTRAINT PK_COACH PRIMARY KEY (id_coach),
    CONSTRAINT UQ_COACH_email UNIQUE (email),
    CONSTRAINT CK_COACH_estado 
        CHECK (estado IN ('Activo', 'Inactivo', 'Suspendido'))
);
GO


-- TABLA 2: NIVEL_ALUMNO

CREATE TABLE dbo.NIVEL_ALUMNO (
    id_nivel_alumno INT IDENTITY(1,1) NOT NULL,
    nombre_nivel NVARCHAR(50) NOT NULL,
    porcentaje_incremento_base DECIMAL(5,2) NOT NULL,
    descripcion NVARCHAR(250),

    CONSTRAINT PK_NIVEL_ALUMNO PRIMARY KEY (id_nivel_alumno),
    CONSTRAINT UQ_NIVEL_ALUMNO_nombre UNIQUE (nombre_nivel),
    CONSTRAINT CK_NIVEL_ALUMNO_porcentaje 
        CHECK (porcentaje_incremento_base > 0 AND porcentaje_incremento_base <= 100)
);
GO


--  TABLA 3: ALUMNO
  
CREATE TABLE dbo.ALUMNO (
    id_alumno INT IDENTITY(1,1) NOT NULL,
    id_coach INT NOT NULL,
    id_nivel_alumno INT NOT NULL,
    nombre NVARCHAR(80) NOT NULL,
    apellido NVARCHAR(80) NOT NULL,
    email NVARCHAR(120) NOT NULL,
    objetivo NVARCHAR(120) NULL,
    estado NVARCHAR(20) NOT NULL CONSTRAINT DF_ALUMNO_estado DEFAULT 'Activo',
    fecha_alta DATE NOT NULL CONSTRAINT DF_ALUMNO_fecha_alta DEFAULT CAST(GETDATE() AS DATE),

    CONSTRAINT PK_ALUMNO PRIMARY KEY (id_alumno),
    CONSTRAINT UQ_ALUMNO_email UNIQUE (email),

    CONSTRAINT FK_ALUMNO_COACH 
        FOREIGN KEY (id_coach) REFERENCES dbo.COACH(id_coach),

    CONSTRAINT FK_ALUMNO_NIVEL_ALUMNO 
        FOREIGN KEY (id_nivel_alumno) REFERENCES dbo.NIVEL_ALUMNO(id_nivel_alumno),

    CONSTRAINT CK_ALUMNO_estado 
        CHECK (estado IN ('Activo', 'Pausado', 'Baja'))
);
GO


--  TABLA 4: RUTINA
   

CREATE TABLE dbo.RUTINA (
    id_rutina INT IDENTITY(1,1) NOT NULL,
    id_alumno INT NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,
    objetivo NVARCHAR(120) NULL,
    estado NVARCHAR(20) NOT NULL CONSTRAINT DF_RUTINA_estado DEFAULT 'Activa',

    CONSTRAINT PK_RUTINA PRIMARY KEY (id_rutina),

    CONSTRAINT FK_RUTINA_ALUMNO 
        FOREIGN KEY (id_alumno) REFERENCES dbo.ALUMNO(id_alumno),

    CONSTRAINT CK_RUTINA_estado 
        CHECK (estado IN ('Activa', 'Finalizada', 'Pausada')),

    CONSTRAINT CK_RUTINA_fechas 
        CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);
GO


-- TABLA 5: EJERCICIO

CREATE TABLE dbo.EJERCICIO (
    id_ejercicio INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    grupo_muscular NVARCHAR(80) NOT NULL,
    tipo_ejercicio NVARCHAR(50) NOT NULL,
    descripcion NVARCHAR(250),

    CONSTRAINT PK_EJERCICIO PRIMARY KEY (id_ejercicio),
    CONSTRAINT UQ_EJERCICIO_nombre UNIQUE (nombre)
);
GO


--  TABLA 6: RUTINA_EJERCICIO

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


-- TABLA 7: SESION_ENTRENAMIENTO

CREATE TABLE dbo.SESION_ENTRENAMIENTO (
    id_sesion INT IDENTITY(1,1) NOT NULL,
    id_alumno INT NOT NULL,
    fecha DATE NOT NULL,
    estado_sesion NVARCHAR(20) NOT NULL CONSTRAINT DF_SESION_estado DEFAULT 'Completa',
    comentarios_generales NVARCHAR(300) NULL,

    CONSTRAINT PK_SESION_ENTRENAMIENTO PRIMARY KEY (id_sesion),

    CONSTRAINT FK_SESION_ENTRENAMIENTO_ALUMNO 
        FOREIGN KEY (id_alumno) REFERENCES dbo.ALUMNO(id_alumno),

    CONSTRAINT CK_SESION_ENTRENAMIENTO_estado 
        CHECK (estado_sesion IN ('Completa', 'Parcial', 'Cancelada'))
);
GO


-- TABLA 8: REGISTRO_EJERCICIO

CREATE TABLE dbo.REGISTRO_EJERCICIO (
    id_registro INT IDENTITY(1,1) NOT NULL,
    id_sesion INT NOT NULL,
    id_rutina_ejercicio INT NOT NULL,
    series_realizadas INT NOT NULL,
    repeticiones_realizadas INT NOT NULL,
    peso_utilizado DECIMAL(6,2) NOT NULL,
    rir_promedio INT NOT NULL,
    completado BIT NOT NULL CONSTRAINT DF_REGISTRO_completado DEFAULT 0,
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


--   TABLA 9: SUGERENCIA_PROGRESION

CREATE TABLE dbo.SUGERENCIA_PROGRESION (
    id_sugerencia INT IDENTITY(1,1) NOT NULL,
    id_alumno INT NOT NULL,
    id_ejercicio INT NOT NULL,
    fecha_sugerencia DATE NOT NULL CONSTRAINT DF_SUGERENCIA_fecha DEFAULT CAST(GETDATE() AS DATE),
    peso_actual DECIMAL(6,2) NOT NULL,
    peso_sugerido DECIMAL(6,2) NOT NULL,
    porcentaje_incremento DECIMAL(5,2) NOT NULL,
    motivo NVARCHAR(300) NOT NULL,
    estado NVARCHAR(20) NOT NULL CONSTRAINT DF_SUGERENCIA_estado DEFAULT 'Pendiente',

    CONSTRAINT PK_SUGERENCIA_PROGRESION PRIMARY KEY (id_sugerencia),

    CONSTRAINT FK_SUGERENCIA_ALUMNO 
        FOREIGN KEY (id_alumno) REFERENCES dbo.ALUMNO(id_alumno),

    CONSTRAINT FK_SUGERENCIA_EJERCICIO 
        FOREIGN KEY (id_ejercicio) REFERENCES dbo.EJERCICIO(id_ejercicio),

    CONSTRAINT CK_SUGERENCIA_peso_actual 
        CHECK (peso_actual >= 0),

    CONSTRAINT CK_SUGERENCIA_peso_sugerido 
        CHECK (peso_sugerido >= 0),

    CONSTRAINT CK_SUGERENCIA_porcentaje 
        CHECK (porcentaje_incremento > 0 AND porcentaje_incremento <= 100),

    CONSTRAINT CK_SUGERENCIA_estado 
        CHECK (estado IN ('Pendiente', 'Aprobada', 'Rechazada', 'Aplicada'))
);
GO


--  TABLA 10: HISTORIAL_PROGRESION

CREATE TABLE dbo.HISTORIAL_PROGRESION (
    id_historial INT IDENTITY(1,1) NOT NULL,
    id_sugerencia INT NOT NULL,
    fecha_resolucion DATE NOT NULL CONSTRAINT DF_HISTORIAL_fecha DEFAULT CAST(GETDATE() AS DATE),
    accion_tomada NVARCHAR(30) NOT NULL,
    peso_anterior DECIMAL(6,2) NOT NULL,
    peso_nuevo DECIMAL(6,2) NOT NULL,
    observaciones NVARCHAR(300) NULL,

    CONSTRAINT PK_HISTORIAL_PROGRESION PRIMARY KEY (id_historial),

    CONSTRAINT FK_HISTORIAL_SUGERENCIA 
        FOREIGN KEY (id_sugerencia) REFERENCES dbo.SUGERENCIA_PROGRESION(id_sugerencia),

    CONSTRAINT UQ_HISTORIAL_id_sugerencia UNIQUE (id_sugerencia),

    CONSTRAINT CK_HISTORIAL_accion 
        CHECK (accion_tomada IN ('Aprobada', 'Rechazada', 'Modificada')),

    CONSTRAINT CK_HISTORIAL_peso_anterior 
        CHECK (peso_anterior >= 0),

    CONSTRAINT CK_HISTORIAL_peso_nuevo 
        CHECK (peso_nuevo >= 0)
);
GO


/* ============================================================
   ÍNDICES RECOMENDADOS PARA CONSULTAS Y JOINS
   ============================================================ */

CREATE INDEX IX_ALUMNO_id_coach 
ON dbo.ALUMNO(id_coach);

CREATE INDEX IX_ALUMNO_id_nivel_alumno 
ON dbo.ALUMNO(id_nivel_alumno);

CREATE INDEX IX_RUTINA_id_alumno 
ON dbo.RUTINA(id_alumno);

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

CREATE INDEX IX_SUGERENCIA_id_alumno_estado 
ON dbo.SUGERENCIA_PROGRESION(id_alumno, estado);

CREATE INDEX IX_SUGERENCIA_id_ejercicio 
ON dbo.SUGERENCIA_PROGRESION(id_ejercicio);
GO
