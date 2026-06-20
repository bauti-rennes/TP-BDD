USE CoachesOnlineDB;
GO

/*
=============================================================
  SECCIÓN 17c – DATOS DE PRUEBA
  TP Integrador – Ingeniería de Datos I – UADE
  Docente: Ing. Franco Salazar

  Orden de inserción respeta dependencias de FK:
    1. EJERCICIO            (12 filas, sin dependencias)
    2. COACH                (10 filas)
    3. ALUMNO               (10 filas, FK → COACH, NIVEL_ALUMNO, OBJETIVO_ENTRENAMIENTO)
    4. RUTINA               (12 filas, FK → ALUMNO, OBJETIVO_ENTRENAMIENTO)
    5. RUTINA_EJERCICIO     (24 filas, FK → RUTINA, EJERCICIO)
    6. SESION_ENTRENAMIENTO (12 filas, FK → ALUMNO)
    7. REGISTRO_EJERCICIO   (21 filas, FK → SESION, RUTINA_EJERCICIO)
    8. SUGERENCIA_PROGRESION(10 filas, FK → RUTINA_EJERCICIO)
    9. HISTORIAL_PROGRESION ( 6 filas, FK → SUGERENCIA_PROGRESION)

  NOTA: Los triggers se crean en el archivo 17d_ii_triggers.sql
  DESPUÉS de este script para no interferir con las inserciones.

  IDENTITY_INSERT: se usa SET IDENTITY_INSERT ON/OFF para
  controlar los IDs explícitamente y garantizar que todas las
  referencias cruzadas sean correctas.
=============================================================
*/


-- ============================================================
-- 1. EJERCICIO (12 filas)
-- Los IDs 1–12 son referenciados por RUTINA_EJERCICIO.
-- ============================================================
SET IDENTITY_INSERT dbo.EJERCICIO ON;
INSERT INTO dbo.EJERCICIO (id_ejercicio, nombre, grupo_muscular, tipo_ejercicio, descripcion) VALUES
( 1, N'Sentadilla',            N'Cuádriceps / Glúteos',  N'Compuesto',     N'Sentadilla con barra en espalda alta o baja.'),
( 2, N'Press Banca',           N'Pectorales / Tríceps',  N'Compuesto',     N'Press de banca plano con barra.'),
( 3, N'Peso Muerto',           N'Espalda Baja / Isquios',N'Compuesto',     N'Peso muerto convencional con barra.'),
( 4, N'Press Militar',         N'Hombros / Tríceps',     N'Compuesto',     N'Press por encima de la cabeza con barra de pie.'),
( 5, N'Remo con Barra',        N'Espalda / Bíceps',      N'Compuesto',     N'Remo inclinado con barra pronado.'),
( 6, N'Dominadas',             N'Espalda / Bíceps',      N'Peso Corporal', N'Dominadas con agarre prono o neutro.'),
( 7, N'Hip Thrust',            N'Glúteos / Isquios',     N'Aislado',       N'Hip thrust con barra apoyada en banco.'),
( 8, N'Plancha',               N'Core',                  N'Peso Corporal', N'Plancha isométrica sobre antebrazos.'),
( 9, N'Zancadas',              N'Cuádriceps / Glúteos',  N'Funcional',     N'Zancadas alternas con mancuernas.'),
(10, N'Press Banca Inclinado', N'Pectorales / Hombros',  N'Compuesto',     N'Press inclinado a 35° con barra.'),
(11, N'Curl de Bíceps',        N'Bíceps',                N'Aislado',       N'Curl de bíceps con barra o mancuernas.'),
(12, N'Extensión de Tríceps',  N'Tríceps',               N'Aislado',       N'Extensión de tríceps en polea alta.');
SET IDENTITY_INSERT dbo.EJERCICIO OFF;
GO


-- ============================================================
-- 2. COACH (10 filas)
-- Coach 7 (Diego Fernández) está Inactivo para demostrar
-- la validación en SP_InsertAlumno y el trigger de sesiones.
-- ============================================================
SET IDENTITY_INSERT dbo.COACH ON;
INSERT INTO dbo.COACH (id_coach, nombre, apellido, email, especialidad, id_estado_coach) VALUES
( 1, N'Ana',       N'García',    N'ana.garcia@coachesonline.com',       N'Fuerza y Powerlifting',    1),
( 2, N'Martín',    N'López',     N'martin.lopez@coachesonline.com',     N'Hipertrofia y Culturismo', 1),
( 3, N'Sofía',     N'Martínez',  N'sofia.martinez@coachesonline.com',   N'Recomposición Corporal',   1),
( 4, N'Carlos',    N'Rodríguez', N'carlos.rodriguez@coachesonline.com', N'Rendimiento Deportivo',    1),
( 5, N'Laura',     N'Fernández', N'laura.fernandez@coachesonline.com',  N'Salud y Bienestar',        1),
( 6, N'Diego',     N'Pérez',     N'diego.perez@coachesonline.com',      N'Hipertrofia y Fuerza',     1),
( 7, N'Diego',     N'Fernández', N'diego.fernandez@coachesonline.com',  N'Fuerza General',           2), -- Inactivo
( 8, N'Pablo',     N'González',  N'pablo.gonzalez@coachesonline.com',   N'Powerlifting',             1),
( 9, N'Valentina', N'Torres',    N'valentina.torres@coachesonline.com', N'Funcional y Salud',        1),
(10, N'Rodrigo',   N'Sánchez',   N'rodrigo.sanchez@coachesonline.com',  N'Recomposición Corporal',   1);
SET IDENTITY_INSERT dbo.COACH OFF;
GO


-- ============================================================
-- 3. ALUMNO (10 filas)
-- Niveles  : 1=Novato, 2=Intermedio, 3=Avanzado
-- Objetivos: 1=Fuerza, 2=Hipertrofia, 3=Rendimiento,
--            4=Recomposición corporal, 5=Salud general
-- Coach 7 (Inactivo) es deliberadamente omitido.
-- ============================================================
SET IDENTITY_INSERT dbo.ALUMNO ON;
INSERT INTO dbo.ALUMNO
    (id_alumno, id_coach, id_nivel_alumno, id_objetivo_entrenamiento,
     id_estado_alumno, nombre, apellido, email, fecha_alta) VALUES
( 1,  1, 3, 1, 1, N'Marcos',    N'Ruiz',    N'marcos.ruiz@fitmail.com',      '2025-01-08'),
( 2,  1, 2, 2, 1, N'Elena',     N'Castro',  N'elena.castro@fitmail.com',     '2025-01-10'),
( 3,  2, 1, 5, 1, N'Lucas',     N'Moreno',  N'lucas.moreno@fitmail.com',     '2025-02-01'),
( 4,  3, 2, 4, 1, N'Camila',    N'Vega',    N'camila.vega@fitmail.com',      '2025-02-10'),
( 5,  4, 3, 3, 1, N'Sebastián', N'Díaz',    N'sebastian.diaz@fitmail.com',   '2025-02-15'),
( 6,  5, 1, 2, 1, N'Valentina', N'Ríos',    N'valentina.rios@fitmail.com',   '2025-02-20'),
( 7,  6, 2, 2, 1, N'Tomás',     N'Méndez',  N'tomas.mendez@fitmail.com',     '2025-03-01'),
( 8,  8, 3, 1, 1, N'Diego',     N'Herrera', N'diego.herrera@fitmail.com',    '2025-03-05'),
( 9,  9, 1, 5, 1, N'Florencia', N'Giménez', N'florencia.gimenez@fitmail.com','2025-03-10'),
(10, 10, 2, 4, 1, N'Nicolás',   N'Ibáñez',  N'nicolas.ibanez@fitmail.com',   '2025-03-15');
SET IDENTITY_INSERT dbo.ALUMNO OFF;
GO


-- ============================================================
-- 4. RUTINA (12 filas)
-- Rutinas 1–2: Finalizadas (id_estado_rutina = 2), con fecha_fin.
--              Representan ciclos anteriores del alumno 1 y 2.
-- Rutinas 3–12: Activas (id_estado_rutina = 1), una por alumno.
--              El índice filtrado UX_RUTINA_activa_por_alumno
--              garantiza que no existan dos activas por alumno.
-- ============================================================
SET IDENTITY_INSERT dbo.RUTINA ON;
INSERT INTO dbo.RUTINA
    (id_rutina, id_alumno, id_objetivo_entrenamiento, id_estado_rutina,
     nombre, fecha_inicio, fecha_fin) VALUES
-- Históricas (finalizadas)
( 1, 1, 1, 2, N'Fuerza Base I',   '2025-01-10', '2025-04-10'),
( 2, 2, 2, 2, N'Hipertrofia I',   '2025-01-15', '2025-04-15'),
-- Activas (una por alumno, 1 al 10)
( 3, 1, 1, 1, N'Fuerza Base II',  '2025-04-15', NULL),
( 4, 2, 2, 1, N'Hipertrofia II',  '2025-04-20', NULL),
( 5, 3, 5, 1, N'Salud General I', '2025-05-01', NULL),
( 6, 4, 4, 1, N'Recomposición I', '2025-05-03', NULL),
( 7, 5, 3, 1, N'Rendimiento I',   '2025-05-05', NULL),
( 8, 6, 2, 1, N'Hipertrofia I',   '2025-05-07', NULL),
( 9, 7, 2, 1, N'Hipertrofia II',  '2025-05-10', NULL),
(10, 8, 1, 1, N'Fuerza Máxima I', '2025-05-12', NULL),
(11, 9, 5, 1, N'Salud General I', '2025-05-15', NULL),
(12,10, 4, 1, N'Recomposición I', '2025-05-18', NULL);
SET IDENTITY_INSERT dbo.RUTINA OFF;
GO


-- ============================================================
-- 5. RUTINA_EJERCICIO (24 filas)
-- IDs 1–24 asignados explícitamente (referenciados por
-- REGISTRO_EJERCICIO y SUGERENCIA_PROGRESION).
--
-- NOTAS sobre pesos:
--   re2  (rutina3, Press Banca Alumno1) → 82.50 kg
--        (sug10 ya fue Aplicada: 80.00 → 82.50)
--   re18 (rutina10, Press Banca Alumno8) → 115.00 kg
--        (sug9 ya fue Aplicada: 110.00 → 115.00)
-- ============================================================
SET IDENTITY_INSERT dbo.RUTINA_EJERCICIO ON;
INSERT INTO dbo.RUTINA_EJERCICIO
    (id_rutina_ejercicio, id_rutina, id_ejercicio,
     series_objetivo, repeticiones_objetivo, peso_sugerido, rir_objetivo, observaciones) VALUES
-- ── Rutina 3 – Alumno 1 (Fuerza / Avanzado) ─────────────────
( 1,  3, 1, 4,  5, 100.00, 2, N'Sentadilla con pausa en el fondo.'),
( 2,  3, 2, 4,  5,  82.50, 2, N'Press banca con agarre cerrado.'),   -- peso actualizado (sug10)
( 3,  3, 3, 3,  5, 120.00, 2, NULL),
-- ── Rutina 4 – Alumno 2 (Hipertrofia / Intermedio) ───────────
( 4,  4, 1, 4,  8,  70.00, 2, N'Bajar lento, 2 seg excéntrica.'),
( 5,  4, 2, 4,  8,  55.00, 2, NULL),
-- ── Rutina 5 – Alumno 3 (Salud General / Novato) ─────────────
( 6,  5, 8, 3,  1,   0.00, 0, N'Plancha isométrica 30 s. Reps = 1 serie cronometrada.'),
( 7,  5, 9, 3, 12,  10.00, 3, N'Mancuernas livianas, foco en técnica.'),
-- ── Rutina 6 – Alumno 4 (Recomposición / Intermedio) ─────────
( 8,  6, 7, 4, 10,  50.00, 2, N'Pausa 1 s en extensión máxima.'),
( 9,  6, 1, 3, 10,  40.00, 3, NULL),
-- ── Rutina 7 – Alumno 5 (Rendimiento / Avanzado) ─────────────
(10,  7, 3, 4,  4, 150.00, 1, N'Peso muerto convencional, arriba explosivo.'),
(11,  7, 4, 4,  6,  60.00, 2, NULL),
-- ── Rutina 8 – Alumno 6 (Hipertrofia / Novato) ───────────────
(12,  8, 3, 3, 10,  40.00, 3, N'Peso muerto rumano para isquios.'),
(13,  8, 5, 3, 10,  40.00, 3, NULL),
-- ── Rutina 9 – Alumno 7 (Hipertrofia / Intermedio) ───────────
(14,  9,10, 4, 10,  40.00, 2, N'Press inclinado 35°.'),
(15,  9,11, 3, 12,  15.00, 2, N'Curl alterno mancuernas.'),
(16,  9,12, 3, 12,  12.50, 2, NULL),
-- ── Rutina 10 – Alumno 8 (Fuerza / Avanzado) ────────────────
(17, 10, 1, 5,  3, 140.00, 1, N'Sentadilla de competencia, equipamiento mínimo.'),
(18, 10, 2, 5,  3, 115.00, 1, N'Press banca pausa en pecho.'),       -- peso actualizado (sug9)
(19, 10, 3, 4,  3, 180.00, 1, NULL),
-- ── Rutina 11 – Alumno 9 (Salud General / Novato) ────────────
(20, 11, 6, 4,  8,   0.00, 2, N'Dominadas con banda asistida si es necesario.'),
(21, 11, 5, 3, 12,  30.00, 3, NULL),
(22, 11,11, 3, 12,  12.50, 2, NULL),
-- ── Rutina 12 – Alumno 10 (Recomposición / Intermedio) ───────
(23, 12, 7, 4, 12,  40.00, 2, NULL),
(24, 12, 8, 3,  1,   0.00, 0, N'Plancha isométrica 45 s.');
SET IDENTITY_INSERT dbo.RUTINA_EJERCICIO OFF;
GO


-- ============================================================
-- 6. SESION_ENTRENAMIENTO (12 filas)
-- Estados: 1=Completa, 2=Parcial, 3=Cancelada
-- La sesión 12 (Cancelada) no tendrá registros de ejercicio.
-- Las sesiones parciales (6, 9) tienen menos registros que
-- la cantidad de ejercicios en su rutina.
-- ============================================================
SET IDENTITY_INSERT dbo.SESION_ENTRENAMIENTO ON;
INSERT INTO dbo.SESION_ENTRENAMIENTO
    (id_sesion, id_alumno, id_estado_sesion, fecha, comentarios_generales) VALUES
( 1,  1, 1, '2025-05-15', N'Primera sesión de la nueva rutina. Buena energía.'),
( 2,  8, 1, '2025-05-20', N'Solo realizó sentadilla por tiempo. Fuerte comienzo.'),
( 3,  1, 1, '2025-06-01', N'Sesión completa. RIR 1 en Press, señal para progresar.'),
( 4,  2, 1, '2025-06-02', N'Sesión completa. Técnica sólida en ambos ejercicios.'),
( 5,  3, 1, '2025-06-02', N'Novato completó plancha 30 s y zancadas sin dificultad.'),
( 6,  4, 2, '2025-06-03', N'Sesión parcial: solo Hip Thrust, alumno sin tiempo.'),
( 7,  5, 1, '2025-06-03', N'Rendimiento máximo, RIR 1 en peso muerto.'),
( 8,  6, 1, '2025-06-04', N'Sesión completa con buen volumen para novato.'),
( 9,  7, 2, '2025-06-04', N'Sesión parcial: solo press inclinado completado.'),
(10,  8, 1, '2025-06-05', N'Triple completo. 142.5 kg sentadilla a RIR 0: progresión inminente.'),
(11,  9, 1, '2025-06-05', N'Dominadas y remo completos. Curl omitido por tiempo.'),
(12, 10, 3, '2025-06-06', N'Sesión cancelada por indisposición del alumno.');
SET IDENTITY_INSERT dbo.SESION_ENTRENAMIENTO OFF;
GO


-- ============================================================
-- 7. REGISTRO_EJERCICIO (21 filas)
-- Total por sesión:
--   Sesión  1 → 2 registros (re1, re2)
--   Sesión  2 → 1 registro  (re17)
--   Sesión  3 → 3 registros (re1, re2, re3)   ← sesión completa
--   Sesión  4 → 2 registros (re4, re5)
--   Sesión  5 → 2 registros (re6, re7)
--   Sesión  6 → 1 registro  (re8)              ← parcial
--   Sesión  7 → 2 registros (re10, re11)
--   Sesión  8 → 2 registros (re12, re13)
--   Sesión  9 → 1 registro  (re14)             ← parcial
--   Sesión 10 → 3 registros (re17, re18, re19) ← completa
--   Sesión 11 → 2 registros (re20, re21)
--   Sesión 12 → 0 registros                    ← cancelada
--   Total = 21 ✓
-- ============================================================
SET IDENTITY_INSERT dbo.REGISTRO_EJERCICIO ON;
INSERT INTO dbo.REGISTRO_EJERCICIO
    (id_registro, id_sesion, id_rutina_ejercicio,
     series_realizadas, repeticiones_realizadas, peso_utilizado, rir_promedio, observaciones) VALUES

-- Sesión 1 – Alumno 1 (2025-05-15)
( 1,  1,  1, 4, 5, 100.00, 2, N'Sentadilla sólida, buena profundidad.'),
( 2,  1,  2, 4, 5,  80.00, 2, N'Press dentro del objetivo.'),

-- Sesión 2 – Alumno 8 (2025-05-20, sesión incompleta por tiempo)
( 3,  2, 17, 5, 3, 140.00, 1, N'Solo completó sentadilla. Fuerte comienzo.'),

-- Sesión 3 – Alumno 1 (2025-06-01, sesión completa)
( 4,  3,  1, 4, 5, 100.00, 1, N'Misma carga, RIR mejoró a 1: señal de adaptación.'),
( 5,  3,  2, 4, 5,  80.00, 1, N'RIR bajó a 1, coach sugirió progresión.'),
( 6,  3,  3, 3, 5, 120.00, 2, N'Peso muerto sin dificultad.'),

-- Sesión 4 – Alumno 2 (2025-06-02)
( 7,  4,  4, 4, 8,  70.00, 2, NULL),
( 8,  4,  5, 4, 8,  55.00, 2, N'Press banca fluido. Listo para subir carga.'),

-- Sesión 5 – Alumno 3 (2025-06-02)
( 9,  5,  6, 3, 1,   0.00, 0, N'Plancha mantenida 30 s en las 3 series.'),
(10,  5,  7, 3,12,  10.00, 3, N'Zancadas con buena base de soporte.'),

-- Sesión 6 – Alumno 4 (2025-06-03, PARCIAL: solo un ejercicio)
(11,  6,  8, 4,10,  50.00, 2, N'Solo realizó Hip Thrust.'),

-- Sesión 7 – Alumno 5 (2025-06-03)
(12,  7, 10, 4, 4, 150.00, 1, N'RIR 1. Cerca del límite actual.'),
(13,  7, 11, 4, 6,  60.00, 2, N'Press militar controlado.'),

-- Sesión 8 – Alumno 6 (2025-06-04)
(14,  8, 12, 3,10,  40.00, 3, NULL),
(15,  8, 13, 3,10,  40.00, 3, NULL),

-- Sesión 9 – Alumno 7 (2025-06-04, PARCIAL: solo primer ejercicio)
(16,  9, 14, 4,10,  40.00, 2, N'Solo press inclinado. Buen control.'),

-- Sesión 10 – Alumno 8 (2025-06-05, sesión completa)
(17, 10, 17, 5, 3, 142.50, 0, N'Sentadilla a RIR 0: superó objetivo de carga.'),
(18, 10, 18, 5, 3, 112.50, 1, N'Press banca 2.5 kg por encima del objetivo.'),
(19, 10, 19, 4, 3, 182.50, 1, N'Peso muerto nuevo máximo personal.'),

-- Sesión 11 – Alumno 9 (2025-06-05)
(20, 11, 20, 4, 8,   0.00, 2, N'Dominadas con banda nivel 1.'),
(21, 11, 21, 3,12,  30.00, 3, NULL);

-- Sesión 12 – Alumno 10 (2025-06-06) → SIN REGISTROS (Cancelada)

SET IDENTITY_INSERT dbo.REGISTRO_EJERCICIO OFF;
GO


-- ============================================================
-- 8. SUGERENCIA_PROGRESION (10 filas)
--
-- Estados:
--   1 = Pendiente : coach debe revisar
--   2 = Aprobada  : aprobada pero no aplicada aún en rutina
--   3 = Rechazada : descartada por el coach
--   4 = Aplicada  : peso ya actualizado en RUTINA_EJERCICIO
--
-- Distribución:
--   Pendientes (4): sug1(re1), sug2(re17), sug7(re4), sug8(re8)
--                   → todos sobre re distintos → UX no violado
--   Aprobadas  (2): sug3(re3), sug4(re5)
--   Rechazadas (2): sug5(re10), sug6(re12)
--   Aplicadas  (2): sug9(re18), sug10(re2)
--                   → pesos ya reflejados en RUTINA_EJERCICIO
-- ============================================================
SET IDENTITY_INSERT dbo.SUGERENCIA_PROGRESION ON;
INSERT INTO dbo.SUGERENCIA_PROGRESION
    (id_sugerencia, id_rutina_ejercicio, id_estado_sugerencia, fecha_sugerencia,
     peso_actual, peso_sugerido, porcentaje_incremento, motivo) VALUES

-- PENDIENTES
( 1,  1, 1, '2025-06-06', 100.00, 102.50, 2.50,
    N'Alumno completó 4×5 a RIR 1; incremento 2.5% acorde a nivel Avanzado.'),
( 2, 17, 1, '2025-06-06', 140.00, 145.00, 3.57,
    N'Sentadilla a RIR 0 en última sesión; carga moderada recomendada.'),
( 7,  4, 1, '2025-06-07',  70.00,  75.00, 7.14,
    N'Alumno Intermedio completó sentadilla con facilidad; +5 kg justificado.'),
( 8,  8, 1, '2025-06-08',  50.00,  52.50, 5.00,
    N'Hip Thrust al objetivo con margen; incremento de 2.5 kg sugerido.'),

-- APROBADAS (historial de aprobación en HISTORIAL_PROGRESION, peso aún no aplicado)
( 3,  3, 2, '2025-06-01', 120.00, 122.50, 2.08,
    N'Peso muerto completado sin dificultad; incremento conservador.'),
( 4,  5, 2, '2025-06-06',  55.00,  57.50, 4.55,
    N'Press banca completado con margen; aumento de 2.5 kg justificado.'),

-- RECHAZADAS
( 5, 10, 3, '2025-06-06', 150.00, 155.00, 3.33,
    N'RIR 1 sugiere margen, pero coach consideró riesgoso avanzar esta semana.'),
( 6, 12, 3, '2025-06-07',  40.00,  42.50, 6.25,
    N'Novato con técnica en desarrollo; incremento postergado hasta consolidación.'),

-- APLICADAS (peso ya actualizado en re2 y re18 respectivamente)
( 9, 18, 4, '2025-06-10', 110.00, 115.00, 4.55,
    N'Press banca 5×3 a RIR 1 con carga superior al objetivo; progresión a 115 kg.'),
(10,  2, 4, '2025-06-10',  80.00,  82.50, 3.13,
    N'Press banca 4×5 con RIR reducido dos sesiones seguidas; +2.5 kg aprobado.');
SET IDENTITY_INSERT dbo.SUGERENCIA_PROGRESION OFF;
GO


-- ============================================================
-- 9. HISTORIAL_PROGRESION (6 filas)
-- Registra la resolución de: sug3, sug4 (Aprobadas),
-- sug5, sug6 (Rechazadas) y sug9, sug10 (Aplicadas).
--
-- Para rechazadas: peso_nuevo = peso_anterior (sin cambio real
-- en la prescripción; el rechazo no modifica la rutina).
-- Para aprobadas/aplicadas: peso_nuevo = peso sugerido aprobado.
--
-- Las sugerencias Pendientes (sug1, sug2, sug7, sug8) aún no
-- tienen historial porque están sin resolver.
-- ============================================================
SET IDENTITY_INSERT dbo.HISTORIAL_PROGRESION ON;
INSERT INTO dbo.HISTORIAL_PROGRESION
    (id_historial, id_sugerencia, id_accion_progresion, fecha_resolucion,
     peso_anterior, peso_nuevo, observaciones) VALUES
(1,  3, 1, '2025-06-06', 120.00, 122.50, N'Aprobada. Se aplicará en la próxima carga.'),
(2,  4, 1, '2025-06-11',  55.00,  57.50, N'Aprobada por Ana García.'),
(3,  5, 2, '2025-06-06', 150.00, 150.00, N'Rechazada: prioridad en técnica antes de aumentar carga.'),
(4,  6, 2, '2025-06-11',  40.00,  40.00, N'Rechazada: alumno novato, técnica aún inestable.'),
(5,  9, 1, '2025-06-11', 110.00, 115.00, N'Aprobada y aplicada. Rutina actualizada.'),
(6, 10, 1, '2025-06-11',  80.00,  82.50, N'Aprobada y aplicada. Rutina actualizada.');
SET IDENTITY_INSERT dbo.HISTORIAL_PROGRESION OFF;
GO
