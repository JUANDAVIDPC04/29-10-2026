-- =====================================================================
-- Poblado de datos para la base `distrito a`  (MariaDB 10.11)
-- Genera: ~1.500 clientes y ~14.000 citas (mínimo 10.000)
-- Ejecutar DESPUÉS de crear las tablas (01_schema.sql).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- PARÁMETROS (ajústalos si quieres)
-- ---------------------------------------------------------------------
SET @num_clientes  = 1500;                 -- cantidad de clientes
SET @num_barberos  = 5;                    -- IDs de barbero: 1..5 (deben existir en tu tabla de barberos)
SET @fecha_ini     = '2025-11-01';         -- primera fecha de citas
SET @fecha_fin     = '2026-11-30';         -- última fecha de citas
SET @ahora         = '2026-10-29 14:46:00';-- "momento actual": antes = citas pasadas, después = futuras
SET @reg_ini       = '2024-01-01';         -- fecha de registro del primer cliente

-- Opcional: limpiar datos previos
-- DELETE FROM `cita`;
-- DELETE FROM `cliente`;

-- ---------------------------------------------------------------------
-- 0) Tabla auxiliar de números 0..9999
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_numeros;
CREATE TABLE tmp_numeros (n INT NOT NULL PRIMARY KEY) ENGINE=InnoDB;

INSERT INTO tmp_numeros (n)
SELECT a.d + b.d * 10 + c.d * 100 + e.d * 1000
FROM (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a,
     (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b,
     (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c,
     (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) e;

-- ---------------------------------------------------------------------
-- 1) CLIENTES
--    Nombres y apellidos colombianos, celular de 10 dígitos (3XX XXXXXXX).
--    FechaRegistro crece con el ID (clientes nuevos = IDs altos).
-- ---------------------------------------------------------------------
INSERT INTO `cliente` (`ID_Cliente`, `Nombre`, `Apellido`, `Telefono`, `Email`, `FechaRegistro`)
SELECT
  n,
  ELT(1 + FLOOR(RAND() * 40),
    'Juan','Carlos','Andrés','Camilo','Santiago','Sebastián','Daniel','David','Felipe','Jhon',
    'Brayan','Kevin','Alejandro','Mateo','Nicolás','Julián','Diego','Esteban','Cristian','Jorge',
    'Luis','Miguel','Johan','Samuel','Emmanuel','Yeison','Wilmer','Fabián','Óscar','Hernán',
    'Mauricio','Ricardo','Jairo','Edwin','Víctor','Sergio','Iván','Álvaro','Gustavo','Leonardo'),
  ELT(1 + FLOOR(RAND() * 40),
    'Rodríguez','Gómez','Martínez','López','García','Hernández','González','Pérez','Sánchez','Ramírez',
    'Torres','Díaz','Vargas','Castro','Rojas','Moreno','Jiménez','Ruiz','Ortiz','Gutiérrez',
    'Muñoz','Álvarez','Romero','Suárez','Herrera','Medina','Cárdenas','Cortés','Peña','Rincón',
    'Acosta','Salazar','Quintero','Beltrán','Parra','Ospina','Cardona','Giraldo','Mejía','Valencia'),
  CONCAT('3',
         ELT(1 + FLOOR(RAND() * 8), '00','10','15','20','50','04','12','24'),
         LPAD(FLOOR(RAND() * 10000000), 7, '0')),
  CONCAT('pendiente', n),                                   -- se reemplaza abajo
  DATE_ADD(@reg_ini, INTERVAL FLOOR((n - 1) * DATEDIFF(@ahora, @reg_ini) / @num_clientes) DAY)
FROM tmp_numeros
WHERE n BETWEEN 1 AND @num_clientes;

-- Emails: nombre + separador + apellido + ID @ dominio (sin tildes ni ñ)
UPDATE `cliente`
SET `Email` = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(`Nombre`),
      'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u'),'ñ','n');

UPDATE `cliente`
SET `Email` = CONCAT(`Email`,
      ELT(1 + MOD(`ID_Cliente`, 3), '.', '', '_'),
      REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(`Apellido`),
      'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u'),'ñ','n'));

UPDATE `cliente`
SET `Email` = CONCAT(`Email`, `ID_Cliente`, '@',
      CASE
        WHEN MOD(`ID_Cliente` * 37, 100) < 60 THEN 'gmail.com'
        WHEN MOD(`ID_Cliente` * 37, 100) < 75 THEN 'hotmail.com'
        WHEN MOD(`ID_Cliente` * 37, 100) < 85 THEN 'outlook.com'
        WHEN MOD(`ID_Cliente` * 37, 100) < 93 THEN 'yahoo.com'
        ELSE 'icloud.com'
      END);

-- ---------------------------------------------------------------------
-- 2) CITAS
--    Parrilla: lunes a sábado, 9:00 a 18:30 (cada 30 min), por barbero.
--    Cada franja se ocupa con probabilidad variable (más demanda en la
--    tarde y los sábados, menos al mediodía y los lunes). Así NUNCA hay
--    dos citas para el mismo barbero a la misma hora.
--    No se trabaja domingos, 25-dic ni 1-ene.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_citas;
CREATE TABLE tmp_citas (
  FechaHoraCita DATETIME NOT NULL,
  FK_ID_Barbero INT NOT NULL,
  r_cli DOUBLE NOT NULL,
  r_srv DOUBLE NOT NULL,
  r_est DOUBLE NOT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_citas (FechaHoraCita, FK_ID_Barbero, r_cli, r_srv, r_est)
SELECT
  TIMESTAMP(DATE_ADD(@fecha_ini, INTERVAL d.n DAY), SEC_TO_TIME(32400 + s.n * 1800)),
  b.n,
  RAND(), RAND(), RAND()
FROM tmp_numeros d, tmp_numeros b, tmp_numeros s
WHERE d.n BETWEEN 0 AND DATEDIFF(@fecha_fin, @fecha_ini)
  AND b.n BETWEEN 1 AND @num_barberos
  AND s.n BETWEEN 0 AND 19
  AND DAYOFWEEK(DATE_ADD(@fecha_ini, INTERVAL d.n DAY)) <> 1
  AND DATE_FORMAT(DATE_ADD(@fecha_ini, INTERVAL d.n DAY), '%m-%d') NOT IN ('12-25', '01-01')
  AND RAND() <
      CASE
        WHEN (9 + s.n DIV 2) BETWEEN 12 AND 13 THEN 0.28
        WHEN (9 + s.n DIV 2) >= 16             THEN 0.55
        WHEN (9 + s.n DIV 2) BETWEEN 9 AND 10  THEN 0.30
        ELSE 0.42
      END
      *
      CASE DAYOFWEEK(DATE_ADD(@fecha_ini, INTERVAL d.n DAY))
        WHEN 2 THEN 0.80      -- lunes
        WHEN 6 THEN 1.10      -- viernes
        WHEN 7 THEN 1.25      -- sábado
        ELSE 1.00
      END;

-- Inserción final en `cita`
--   * Cliente: solo clientes ya registrados a la fecha de la cita; los
--     más antiguos (IDs bajos) vienen con más frecuencia.
--   * Servicio con pesos realistas.
--   * Estado: pasadas -> Completada/Cancelada/No asistió;
--             futuras -> Confirmada/Pendiente/Cancelada.
INSERT INTO `cita` (`ID_Cita`, `FK_ID_Cliente`, `FK_ID_Barbero`, `FechaHoraCita`, `Servicio`, `Estado`)
SELECT
  ROW_NUMBER() OVER (ORDER BY t.FechaHoraCita, t.FK_ID_Barbero),
  1 + FLOOR(POW(t.r_cli, 1.4) *
        (SELECT COUNT(*) FROM `cliente` k WHERE k.FechaRegistro <= DATE(t.FechaHoraCita))),
  t.FK_ID_Barbero,
  t.FechaHoraCita,
  CASE
    WHEN t.r_srv < 0.35 THEN 'Corte degradado'
    WHEN t.r_srv < 0.55 THEN 'Corte clásico'
    WHEN t.r_srv < 0.70 THEN 'Corte y barba'
    WHEN t.r_srv < 0.80 THEN 'Arreglo de barba'
    WHEN t.r_srv < 0.88 THEN 'Corte infantil'
    WHEN t.r_srv < 0.92 THEN 'Perfilado de cejas'
    WHEN t.r_srv < 0.96 THEN 'Lavado y peinado'
    ELSE 'Mascarilla facial'
  END,
  CASE
    WHEN t.FechaHoraCita < @ahora THEN
      CASE WHEN t.r_est < 0.84 THEN 'Completada'
           WHEN t.r_est < 0.93 THEN 'Cancelada'
           ELSE 'No asistió' END
    ELSE
      CASE WHEN t.r_est < 0.65 THEN 'Confirmada'
           WHEN t.r_est < 0.95 THEN 'Pendiente'
           ELSE 'Cancelada' END
  END
FROM tmp_citas t;

-- ---------------------------------------------------------------------
-- 3) Evitar que un mismo cliente tenga 2 citas el mismo día
--    (se reasigna a otro cliente ya registrado; 4 pasadas)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_dup;
CREATE TABLE tmp_dup (ID_Cita INT NOT NULL PRIMARY KEY) ENGINE=InnoDB;

INSERT INTO tmp_dup
SELECT ID_Cita FROM (
  SELECT ID_Cita, ROW_NUMBER() OVER (PARTITION BY FK_ID_Cliente, DATE(FechaHoraCita) ORDER BY FechaHoraCita) rn
  FROM `cita`) x WHERE rn > 1;
UPDATE `cita` c JOIN tmp_dup d ON d.ID_Cita = c.ID_Cita
SET c.FK_ID_Cliente = 1 + FLOOR(RAND() * (SELECT COUNT(*) FROM `cliente` k WHERE k.FechaRegistro <= DATE(c.FechaHoraCita)));

TRUNCATE TABLE tmp_dup;
INSERT INTO tmp_dup
SELECT ID_Cita FROM (
  SELECT ID_Cita, ROW_NUMBER() OVER (PARTITION BY FK_ID_Cliente, DATE(FechaHoraCita) ORDER BY FechaHoraCita) rn
  FROM `cita`) x WHERE rn > 1;
UPDATE `cita` c JOIN tmp_dup d ON d.ID_Cita = c.ID_Cita
SET c.FK_ID_Cliente = 1 + FLOOR(RAND() * (SELECT COUNT(*) FROM `cliente` k WHERE k.FechaRegistro <= DATE(c.FechaHoraCita)));

TRUNCATE TABLE tmp_dup;
INSERT INTO tmp_dup
SELECT ID_Cita FROM (
  SELECT ID_Cita, ROW_NUMBER() OVER (PARTITION BY FK_ID_Cliente, DATE(FechaHoraCita) ORDER BY FechaHoraCita) rn
  FROM `cita`) x WHERE rn > 1;
UPDATE `cita` c JOIN tmp_dup d ON d.ID_Cita = c.ID_Cita
SET c.FK_ID_Cliente = 1 + FLOOR(RAND() * (SELECT COUNT(*) FROM `cliente` k WHERE k.FechaRegistro <= DATE(c.FechaHoraCita)));

TRUNCATE TABLE tmp_dup;
INSERT INTO tmp_dup
SELECT ID_Cita FROM (
  SELECT ID_Cita, ROW_NUMBER() OVER (PARTITION BY FK_ID_Cliente, DATE(FechaHoraCita) ORDER BY FechaHoraCita) rn
  FROM `cita`) x WHERE rn > 1;
UPDATE `cita` c JOIN tmp_dup d ON d.ID_Cita = c.ID_Cita
SET c.FK_ID_Cliente = 1 + FLOOR(RAND() * (SELECT COUNT(*) FROM `cliente` k WHERE k.FechaRegistro <= DATE(c.FechaHoraCita)));

-- ---------------------------------------------------------------------
-- 4) Limpieza de tablas auxiliares
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_dup;
DROP TABLE IF EXISTS tmp_citas;
DROP TABLE IF EXISTS tmp_numeros;

-- ---------------------------------------------------------------------
-- 5) Verificación rápida
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS total_clientes FROM `cliente`;
SELECT COUNT(*) AS total_citas    FROM `cita`;
SELECT Estado, COUNT(*) AS cantidad FROM `cita` GROUP BY Estado ORDER BY cantidad DESC;
SELECT Servicio, COUNT(*) AS cantidad FROM `cita` GROUP BY Servicio ORDER BY cantidad DESC;
